--
-- Calamath's Quest Tracker [CQT]
--
-- Copyright (c) 2022 Calamath
--
-- This software is released under the Artistic License 2.0
-- https://opensource.org/licenses/Artistic-2.0
--
-- Note :
-- This addon works that uses the library LibAddonMenu-2.0 by sirinsidiator, Seerah, released under the Artistic License 2.0
-- This addon works that uses the library LibCustomMenu by votan.
-- This addon works that uses the library LibMediaProvider by Seerah, released under the LGPL-2.1 license.
-- This addon works that uses the library LibCInteraction by Calamath, released under the Artistic License 2.0
-- You will need to obtain the above libraries separately.
--

-- ---------------------------------------------------------------------------------------
-- Checking dependencies
-- ---------------------------------------------------------------------------------------
local _EXTERNAL_DEPENDENCIES = {
	"LibMediaProvider", 
	"LibAddonMenu2", 
	"LibCInteraction", 
}
for _, objectName in pairs(_EXTERNAL_DEPENDENCIES) do
	assert(_G[objectName], "[CQuestTracker] Fatal Error: " .. objectName .. " not found.")
end


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
-- CT_SimpleAddonFramework: Simple Add-on Framework Template Class              rel.1.1.12
-- ---------------------------------------------------------------------------------------
local CT_SimpleAddonFramework = CT_MinimalAddonFramework:Subclass()
function CT_SimpleAddonFramework:Initialize(name, attributes)
	CT_MinimalAddonFramework.Initialize(self, name, attributes)
	if self._external then
		self._class = {}
		self._shared = nil
		self._external.RegisterClassObject = function(_, ...) self:RegisterClassObject(...) end
	end
end
function CT_SimpleAddonFramework:ConfigDebug(auth)
	local debugMode = false
	auth = auth or self.authority
	if type(auth) == "table" then
		local key = HashString(GetDisplayName())
		for _, v in pairs(auth) do
			if key == v then debugMode = true end
		end
	end
	if debugMode then
		if not self._logger then
			if not IsConsoleUI() and LibDebugLogger then
				self._logger = LibDebugLogger(self._name)
			else
				local Printf = function(_, ...) df(...) end
				self._logger = { Verbose = Printf, Debug = Printf, Info = Printf, Warn = Printf, Error = Printf, }
			end
		end
		self.LDL = self._logger
	else
		local Dummy = function() end
		self.LDL = { Verbose = Dummy, Debug = Dummy, Info = Dummy, Warn = Dummy, Error = Dummy, }
	end
	self._isDebugMode = debugMode
end
function CT_SimpleAddonFramework:RegisterClassObject(className, classObject)
	if className and classObject and not self._class[className] then
		self._class[className] = classObject
		return true
	else
		return false
	end
end
function CT_SimpleAddonFramework:HasAvailableClass(className)
	if className then
		return self._class[className] ~= nil
	end
end
function CT_SimpleAddonFramework:CreateClassObject(className, ...)
	if className and self._class[className] then
		return self._class[className]:New(...)
	end
end


-- ---------------------------------------------------------------------------------------
-- CT_AddonFramework: Add-on Framework Template Class for multiple modules      rel.1.1.12
-- ---------------------------------------------------------------------------------------
local CT_AddonFramework = CT_SimpleAddonFramework:Subclass()
function CT_AddonFramework:Initialize(name, attributes)
	CT_SimpleAddonFramework.Initialize(self, name, attributes)
	if not self._external then return end
	self._shared = {
		name = self._name, 
		version = self.version, 
		author = self.author, 
		LDL = self.LDL, 
		HasAvailableClass = function(_, ...) return self:HasAvailableClass(...) end, 
		CreateClassObject = function(_, ...) return self:CreateClassObject(...) end, 
		RegisterGlobalObject = function(_, ...) return self:RegisterGlobalObject(...) end, 
		RegisterSharedObject = function(_, ...) return self:RegisterSharedObject(...) end, 
	}
	self._external.SetSharedEnvironment = function()
		-- This method is intended to be called in the main chunk and should not be called inside functions.
		self:EnableCustomEnvironment(self._env, 3)	-- [Main Chunk]: self._external:SetSharedEnvironment() -> self:EnableCustomEnvironment(t, 3) -> setfenv(3, t)
		return self._shared
	end
	if self._enableCallback then
		self._callbackObject = ZO_CallbackObject:New()
		self.RegisterCallback = function(self, ...) return self._callbackObject:RegisterCallback(...) end
		self.UnregisterCallback = function(self, ...) return self._callbackObject:UnregisterCallback(...) end
		self.FireCallbacks = function(self, ...) return self._callbackObject:FireCallbacks(...) end
		self._shared.RegisterCallback = function(_, ...) return self._callbackObject:RegisterCallback(...) end
		self._shared.UnregisterCallback = function(_, ...) return self._callbackObject:UnregisterCallback(...) end
		self._shared.FireCallbacks = function(_, ...) return self._callbackObject:FireCallbacks(...) end
		self._external.FireCallbacks = function(_, ...) return self._callbackObject:FireCallbacks(...) end
	end
	if self._enableEnvironment then
		self:EnableCustomEnvironment(self._env, 4)	-- [Main Chunk]: self:New() -> self:Initialize() -> EnableCustomEnvironment(t, 4) -> setfenv(4, t)
	end
end
function CT_AddonFramework:ConfigDebug(auth)
	CT_SimpleAddonFramework.ConfigDebug(self, auth)
	if self._shared then
		self._shared.LDL = self.LDL
	end
end
function CT_AddonFramework:CreateCustomEnvironment(t, parent)	-- helper function
-- This method is intended to be called in the main chunk and should not be called inside functions.
	return setmetatable(type(t) == "table" and t or {}, { __index = type(parent) == "table" and parent or getfenv and type(getfenv) == "function" and getfenv(2) or _ENV or _G, })
end
function CT_AddonFramework:EnableCustomEnvironment(t, stackLevel)	-- helper function
	local stackLevel = type(stackLevel) == "number" and stackLevel > 1 and stackLevel or type(ZO_GetCallstackFunctionNames) == "function" and #(ZO_GetCallstackFunctionNames()) + 1 or 2
	local env = type(t) == "table" and t or type(self._env) == "table" and self._env
	if env then
		if setfenv and type(setfenv) == "function" then
			setfenv(stackLevel, env)
		else
			_ENV = env
		end
	end
end
function CT_AddonFramework:RegisterGlobalObject(objectName, globalObject)
	if objectName and globalObject and _G[objectName] == nil then
		_G[objectName] = globalObject
		return true
	else
		return false
	end
end
function CT_AddonFramework:RegisterSharedObject(objectName, sharedObject)
	if objectName and sharedObject and self._env and not self._env[objectName] then
		self._env[objectName] = sharedObject
		return true
	else
		return false
	end
end


-- ---------------------------------------------------------------------------------------
-- Helper Functions
-- ---------------------------------------------------------------------------------------
local L = GetString

local function Decolorize(str)
	if type(str) == "string" then
		return str:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
	else
		return str
	end
end

local function Colorize(colorDef, str, option)
--	colorDef : ZO_ColorDef object or hexadecimal RGB notation (usually 6 characters, ignoring alpha)
--	str      : string
--	option   : string for specifying feature options [optional]
--				  nil      --> same as ZO_ColorDef:Colorize(), regardless of whether it is colored text or not.
--				 "FILL"    --> fills the entire text with the specified color, including colored text
--				 "DEFAULT" --> passes colored text unchanged and fills only standard color text with specified color
	local rgbHex
	local tbl
	if type(colorDef) == "string" then
		rgbHex = colorDef:match("(%x%x%x%x%x%x)")	-- checking hexadecimal RGB notation
	elseif type(colorDef) == "table" then
		if colorDef.ToHex and colorDef.Colorize then	-- checking ZO_ColorDef
			rgbHex = colorDef:ToHex()
		end
	end
	if rgbHex and type(str) == "string" then
		if option == "FILL" then
			tbl = { "|c", rgbHex, Decolorize(str), "|r" }
		elseif option == "DEFAULT" then
			tbl = { "|c", rgbHex, str:gsub("(|[cC]%x%x%x%x%x%x.-|[rR])", "|r%1|c"..rgbHex), "|r" }
		else
			tbl = { "|c", rgbHex, str, "|r" }
		end
		return tconcat(tbl)
	else
		return str
	end
end

local function RemoveTexture(str)
	if type(str) == "string" then
		return str:gsub("|t[^|]+|t", "")
	else
		return str
	end
end

local cprint, cprintf
local NORMAL_COLOR = "dcdcdc"
if CHAT_ROUTER then
	cprint = function(text)
		pcall(function(text) CHAT_ROUTER:AddSystemMessage(Colorize(NORMAL_COLOR, tostring(text), "DEFAULT")) end, text)
	end
	cprintf = function(text, ...)
		pcall(function(text, ...) CHAT_ROUTER:AddSystemMessage(Colorize(NORMAL_COLOR, text:format(...), "DEFAULT")) end, text, ...)
	end
else
	cprint = d
	cprintf = df
end


-- ---------------------------------------------------------------------------------------
-- CQuestTracker
-- ---------------------------------------------------------------------------------------
local _SHARED_DEFINITIONS = {
	FONT_TYPE	 	= 1, 
	FONT_STYLE		= 2, 
	FONT_SIZE		= 3, 
	FONT_WEIGHT		= 4, 
	UPPER_LIMIT_OF_ASSUMED_QUEST_ID = 50000, 
	UPPER_LIMIT_OF_ASSUMED_POI_ID = 5000, 

	INVALID_ZONE_INDEX = 1, 
	INVALID_ZONE_ID = 2, 

	-- PointOfInterest Database Type
	-- This is a superset of ZoneCompletionType.
	POI_DB_TYPE_NONE					= ZONE_COMPLETION_TYPE_NONE, 					-- 0
	POI_DB_TYPE_PRIORITY_QUEST			= ZONE_COMPLETION_TYPE_PRIORITY_QUESTS, 		-- 1
	POI_DB_TYPE_POINTS_OF_INTEREST		= ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST, 		-- 2
	POI_DB_TYPE_FEATURED_ACHIEVEMENT	= ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS, 	-- 3
	POI_DB_TYPE_WAYSHRINE				= ZONE_COMPLETION_TYPE_WAYSHRINES, 				-- 4	(node POI)
	POI_DB_TYPE_DELVE					= ZONE_COMPLETION_TYPE_DELVES, 					-- 5
	POI_DB_TYPE_GROUP_DELVE				= ZONE_COMPLETION_TYPE_GROUP_DELVES, 			-- 6
	POI_DB_TYPE_SKYSHARD				= ZONE_COMPLETION_TYPE_SKYSHARDS, 				-- 7
	POI_DB_TYPE_WORLD_EVENT				= ZONE_COMPLETION_TYPE_WORLD_EVENTS, 			-- 8
	POI_DB_TYPE_GROUP_BOSS				= ZONE_COMPLETION_TYPE_GROUP_BOSSES, 			-- 9
	POI_DB_TYPE_STRIKING_LOCALE			= ZONE_COMPLETION_TYPE_STRIKING_LOCALES, 		-- 10
	POI_DB_TYPE_MAGES_GUILD_BOOK		= ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS, 		-- 11
	POI_DB_TYPE_MUNDUS_STONE			= ZONE_COMPLETION_TYPE_MUNDUS_STONES, 			-- 12
	POI_DB_TYPE_PUBLIC_DUNGEON			= ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS, 		-- 13
	POI_DB_TYPE_SET_STATION				= ZONE_COMPLETION_TYPE_SET_STATIONS, 			-- 14
	POI_DB_TYPE_NODE					= 100,  -- (node POI)
	POI_DB_TYPE_ARENA_DUNGEON			= 101,  -- (node POI)
	POI_DB_TYPE_GROUP_DUNGEON			= 102,  -- (node POI)
	POI_DB_TYPE_TRIAL_DUNGEON			= 103,  -- (node POI)
	POI_DB_TYPE_HOUSE					= 104,  -- (node POI)

	-- CQuestTracker sounds
	CQT_SOUNDS = {
		FOCUSED							= SOUNDS.QUEST_FOCUSED, 
		PICK_OUT						= SOUNDS.CHAMPION_SPINNER_UP, 
		RULE_OUT						= SOUNDS.CHAMPION_SPINNER_DOWN, 
		ENABLE_PINNING					= SOUNDS.PROMOTIONAL_EVENT_TRACK_ACTIVITY_CLICK, 
		DISABLE_PINNING					= SOUNDS.PROMOTIONAL_EVENT_TRACK_ACTIVITY_UNCLICK, 
		ENABLE_IGNORING					= SOUNDS.GUILD_SELF_LEFT, 
		DISABLE_IGNORING				= SOUNDS.GUILD_SELF_JOINED, 
	}, 
}
local _ENV = CT_AddonFramework:CreateCustomEnvironment(_SHARED_DEFINITIONS)
local CQT = CT_AddonFramework:New("CQuestTracker", {
	name = "CQuestTracker", 
	version = "2.2.8", 
	author = "Calamath", 
	savedVarsSV = "CQuestTrackerSV", 
	savedVarsVersion = 1, 
	activityLogVersion = 2, 
	authority = {2973583419,210970542}, 
	_env = _ENV, 
	_enableCallback = true, 
	_enableEnvironment = true, 
})
-- ---------------------------------------------------------------------------------------
local LibCInteraction = LibCInteraction
local CQT_SV_DEFAULT = {
	accountWide = true, 
	hideFocusedQuestTracker = false, 
	hideCQuestTracker = false, 
	maxNumDisplay = 5, 
	maxNumPinnedQuest = 5, 
	panelAttributes = {
		compactMode = false, 
		clampedToScreen = false, 
		movable = true, 
		offsetX = 400, 
		offsetY = 300, 
		width = 400, 
		height = 600, 
		headerFont = "$(BOLD_FONT)|18|soft-shadow-thick", 
		headerColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL) }, 
		headerColorSelected = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) }, 
		conditionFont = "$(BOLD_FONT)|15|soft-shadow-thick", 
		conditionColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) }, 
		showHintStep = true, 
		hintFont = "$(BOLD_FONT)|15|soft-shadow-thick", 
		hintColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) }, 
		showFocusIcon = false, 
		underlineHeaderOnFocused = true, 
		showTypeIcon = true, 
		enableTypeIconColoring = true, 
		showRepeatableQuestIcon = true, 
		titlebarColor = { 0.4, 0.6666667, 1, 0.7 }, 
		bgColor = { 0, 0, 0, 0 }, 
	}, 
	qhFont = {
		[FONT_TYPE] = "$(BOLD_FONT)", 
		[FONT_STYLE] = "", 
		[FONT_SIZE] = 18, 
		[FONT_WEIGHT] = "soft-shadow-thick", 
	}, 
	qcFont = {
		[FONT_TYPE] = "$(BOLD_FONT)", 
		[FONT_STYLE] = "", 
		[FONT_SIZE] = 15, 
		[FONT_WEIGHT] = "soft-shadow-thick", 
	}, 
	qkFont = {
		[FONT_TYPE] = "$(BOLD_FONT)", 
		[FONT_STYLE] = "", 
		[FONT_SIZE] = 15, 
		[FONT_WEIGHT] = "soft-shadow-thick", 
	}, 
	panelBehavior = {
		minimizeInHUD = false, 
		showInCombat = true, 
		showInBattleground = false, 
		showInGameMenuScene = true, 
	}, 
	qtooltip = {
		show = true, 
		anchor = LEFT, 
	}, 
	qPingAttributes = {
		pingingEnabled = true, 
		pingingOnFocusChange = true, 
		stopPingingOnHidingMapScene = false, 
	}, 
	improveKeybinds = true, 
	cycleAllQuests = false, 
	cycleZoneGuide = false, 
	cycleBackwardsMod1 = KEY_SHIFT, 
	cycleBackwardsMod2 = KEY_GAMEPAD_LEFT_TRIGGER, 
	holdToShowQuestTooltip = true, 
	autoTrackToAddedQuest = true, 
	autoTrackToProgressedQuest = false, 
}

function CQT:OnAddOnLoaded()
--	self.LDL:Debug("EVENT_ADD_ON_LOADED :")
	self.currentApiVersion = GetAPIVersion()
	self.lang = GetCVar("Language.2")
	self.sessionStartTime = { GetTimeStamp(), 0 }
	self.isFirstTimePlayerActivated = true
	self.forceAssistControl = {}

	self.questList = {}
	self.circularJournalIndexList = {}
	self.activityLog = ZO_SavedVars:NewCharacterIdSettings("CQuestTrackerLog", 1, nil, { quest = {}, }, GetWorldName())

	-- CQuestTracker Config
	self.svCurrent = {}
	self.svAccount = ZO_SavedVars:NewAccountWide("CQuestTrackerSV", 1, nil, CQT_SV_DEFAULT, GetWorldName())
	self:ValidateConfigDataSV(self.svAccount)
	if self.svAccount.accountWide then
		self.svCurrent = self.svAccount
	else
		self.svCharacter = ZO_SavedVars:NewCharacterIdSettings("CQuestTrackerSV", 1, nil, CQT_SV_DEFAULT, GetWorldName())
		self:ValidateConfigDataSV(self.svCharacter)
		self.svCurrent = self.svCharacter
	end

	-- quest timer
	self.questTimer = GetQuestTimerManager()

	-- quest ping
	self.questPingManager = GetQuestPingManager and GetQuestPingManager()
	if self.questPingManager then
		self.questPingManager:RegisterOverriddenAttributeTable(self.svCurrent.qPingAttributes)
		self.questPingManager:SetShouldShowOnFocusChangeCallback(function()
			local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
			return self:IsTrackedQuestByIndex(focusedQuestIndex)
		end)
	end

	-- quest tooltip
	self.questTooltip = GetQuestTooltipManager()

	-- tracker panel
	self.trackerPanel = self:CreateClassObject("CQT_TrackerPanel", CQT_UI_TrackerPanel, self.svCurrent.panelAttributes)
	self.trackerPanel:RegisterTitleBarButton("SettingBtn", CQT_SettingButton_OnClicked, L(SI_CQT_TITLEBAR_OPEN_SETTINGS_BUTTON_TIPS))
	self.trackerPanel:RegisterTitleBarButton("QuestListBtn", CQT_QuestListButton_OnClicked, L(SI_CQT_TITLEBAR_QUEST_LIST_BUTTON_TIPS))
	self:AddTrackerPanelFragmentToGameMenuScene()
	HUD_SCENE:AddFragment(self.trackerPanel:GetFragment())
	HUD_UI_SCENE:AddFragment(self.trackerPanel:GetFragment())
	HUD_UI_SCENE:AddFragment(self.trackerPanel:GetTitleBarFragment())
	self.trackerPanel:GetTitleBarFragment():RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_HIDING then
			self.questTooltip:HideQuestTooltip()
		end
	end)
	GAME_MENU_SCENE:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING or newState == SCENE_HIDING then
			self:UpdateTrackerPanelVisibility()
		end
	end)
	if KEYBINDINGS_FRAGMENT then
		KEYBINDINGS_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
			if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_HIDING then
				self:UpdateTrackerPanelVisibility()
			end
		end)
	end

	-- quest journal customizing
	self.questJournalCustomizerKeyboard = self:CreateClassObject("CQuestJournalCustomizer_Keyboard", self.svCurrent)
	self.questJournalCustomizerGamepad = self:CreateClassObject("CQuestJournalCustomizer_Gamepad", self.svCurrent)

	-- LAM setting panel
	self.settingPanel = self:CreateClassObject("CQT_LAMSettingPanel", "CQuestTracker_Options", self.svCurrent, self.svAccount, CQT_SV_DEFAULT)
	self:RegisterCallback("TrackerPanelVisibilitySettingsChanged", function()
		self:UpdateTrackerPanelVisibility()
	end)
	self:RegisterCallback("AddOnSettingsChanged", function(settingCategories)
		self:OnAddOnSettingsChanged(settingCategories)
	end)

	-- focused quest management
	self:InitializeFocusedQuestControlTable()

	-- tutorial
	ZO_Dialogs_RegisterCustomDialog(self.name .. "_WELCOME_MESSAGE", {
		canQueue = true, 
		title = {
			text = "Calamath's Quest Tracker", 
		}, 
		mainText = {
			text = function(dialog)
				return ZO_GenerateParagraphSeparatedList({ L(SI_CQT_WELCOME_TEXT1), L(SI_CQT_WELCOME_TEXT2), L(SI_CQT_WELCOME_TEXT3), L(SI_CQT_WELCOME_TEXT4), })
			end, 
		}, 
		buttons = {
			{
				text = SI_DIALOG_CLOSE, 
			}, 
		},
	})

	-- in-game events
	self:RegisterEvents()

	-- keybinds and interactions
	self:InitializeKeybinds()
	self:RegisterInteractions()
	self.trackerPanel:GetFragment():RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			if self.svCurrent.improveKeybinds then
				PushActionLayerByName("CQT_InteractionSnatcher")
			end
		elseif newState == SCENE_FRAGMENT_HIDING then
			RemoveActionLayerByName("CQT_InteractionSnatcher")
		end
	end)

	-- shared api
	self:RegisterSharedAPI()

	self.LDL:Debug("Initialized: ", self.lang)
end

function CQT:ValidateConfigDataSV(sv)
	-- font size format changes in V2.2.4
	local fontSizeMap
	if self.lang == "jp" or self.lang == "zh" then
		fontSizeMap = {
			["$(KB_14)"] = 12, 
			["$(KB_15)"] = 13, 
			["$(KB_16)"] = 15, 
			["$(KB_17)"] = 15, 
			["$(KB_18)"] = 16, 
			["$(KB_19)"] = 17, 
			["$(KB_20)"] = 18, 
			["$(KB_24)"] = 22, 
		}
	else
		fontSizeMap = {
			["$(KB_14)"] = 14, 
			["$(KB_15)"] = 15, 
			["$(KB_16)"] = 16, 
			["$(KB_17)"] = 17, 
			["$(KB_18)"] = 18, 
			["$(KB_19)"] = 19, 
			["$(KB_20)"] = 20, 
			["$(KB_24)"] = 24, 
		}
	end
	if type(sv.qhFont[FONT_SIZE]) == "string" then
		sv.qhFont[FONT_SIZE] = fontSizeMap[sv.qhFont[FONT_SIZE]] or CQT_SV_DEFAULT.qhFont[FONT_SIZE]
	end
	if type(sv.qcFont[FONT_SIZE]) == "string" then
		sv.qcFont[FONT_SIZE] = fontSizeMap[sv.qcFont[FONT_SIZE]] or CQT_SV_DEFAULT.qcFont[FONT_SIZE]
	end
	if type(sv.qkFont[FONT_SIZE]) == "string" then
		sv.qkFont[FONT_SIZE] = fontSizeMap[sv.qkFont[FONT_SIZE]] or CQT_SV_DEFAULT.qkFont[FONT_SIZE]
	end

	if sv.panelAttributes.compactMode == nil					then sv.panelAttributes.compactMode						= CQT_SV_DEFAULT.panelAttributes.compactMode								end
	if sv.panelAttributes.clampedToScreen == nil				then sv.panelAttributes.clampedToScreen					= CQT_SV_DEFAULT.panelAttributes.clampedToScreen							end
	if sv.panelAttributes.movable == nil						then sv.panelAttributes.movable							= CQT_SV_DEFAULT.panelAttributes.movable									end
	if sv.panelAttributes.headerColorSelected == nil			then sv.panelAttributes.headerColorSelected				= ZO_ShallowTableCopy(CQT_SV_DEFAULT.panelAttributes.headerColorSelected)	end
	if sv.panelAttributes.hintFont == nil						then sv.panelAttributes.hintFont						= sv.panelAttributes.conditionFont											end		-- Derived from conditionFont and added
	if sv.panelAttributes.hintColor == nil						then sv.panelAttributes.hintColor						= ZO_ShallowTableCopy(CQT_SV_DEFAULT.panelAttributes.hintColor)				end
	if sv.panelAttributes.titlebarColor == nil					then sv.panelAttributes.titlebarColor					= ZO_ShallowTableCopy(CQT_SV_DEFAULT.panelAttributes.titlebarColor)			end
	if sv.panelAttributes.showFocusIcon == nil					then sv.panelAttributes.showFocusIcon					= CQT_SV_DEFAULT.panelAttributes.showFocusIcon								end
	if sv.panelAttributes.underlineHeaderOnFocused == nil		then sv.panelAttributes.underlineHeaderOnFocused		= CQT_SV_DEFAULT.panelAttributes.underlineHeaderOnFocused					end
	if sv.panelAttributes.showTypeIcon == nil					then sv.panelAttributes.showTypeIcon					= CQT_SV_DEFAULT.panelAttributes.showTypeIcon								end
	if sv.panelAttributes.enableTypeIconColoring == nil			then sv.panelAttributes.enableTypeIconColoring			= CQT_SV_DEFAULT.panelAttributes.enableTypeIconColoring						end
	if sv.panelAttributes.showRepeatableQuestIcon == nil		then sv.panelAttributes.showRepeatableQuestIcon			= CQT_SV_DEFAULT.panelAttributes.showRepeatableQuestIcon					end
	if sv.qkFont == nil											then sv.qkFont											= ZO_ShallowTableCopy(CQT_SV_DEFAULT.qkFont)								end
	if sv.qPingAttributes == nil								then sv.qPingAttributes									= ZO_ShallowTableCopy(CQT_SV_DEFAULT.qPingAttributes)						end
	if sv.qPingAttributes.stopPingingOnHidingMapScene == nil	then sv.qPingAttributes.stopPingingOnHidingMapScene		= CQT_SV_DEFAULT.qPingAttributes.stopPingingOnHidingMapScene				end

	if sv.improveKeybinds == nil								then sv.improveKeybinds									= CQT_SV_DEFAULT.improveKeybinds											end
	if sv.cycleAllQuests == nil									then sv.cycleAllQuests									= CQT_SV_DEFAULT.cycleAllQuests												end
	if sv.cycleZoneGuide == nil									then sv.cycleZoneGuide									= CQT_SV_DEFAULT.cycleZoneGuide												end
	if sv.cycleBackwardsMod1 == nil								then sv.cycleBackwardsMod1								= CQT_SV_DEFAULT.cycleBackwardsMod1											end
	if sv.cycleBackwardsMod2 == nil								then sv.cycleBackwardsMod2								= CQT_SV_DEFAULT.cycleBackwardsMod2											end
	if sv.holdToShowQuestTooltip == nil							then sv.holdToShowQuestTooltip							= CQT_SV_DEFAULT.holdToShowQuestTooltip										end
	if sv.autoTrackToAddedQuest == nil							then sv.autoTrackToAddedQuest							= CQT_SV_DEFAULT.autoTrackToAddedQuest										end
	if sv.autoTrackToProgressedQuest == nil						then sv.autoTrackToProgressedQuest						= CQT_SV_DEFAULT.autoTrackToProgressedQuest									end
end

function CQT:RegisterEvents()
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function(event, initial)
		self.LDL:Debug("EVENT_PLAYER_ACTIVATED : initial =", initial, ", isFirstTime =", self.isFirstTimePlayerActivated)
		if self.isFirstTimePlayerActivated then
			self.isFirstTimePlayerActivated = false
			if self.settingPanel then
				self.settingPanel:InitializeSettingPanel()
			end
			if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER) ~= not self.svCurrent.hideFocusedQuestTracker then
				SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER, self.svCurrent.hideFocusedQuestTracker and "false" or "true")	-- Override default quest tracker visibility with our save data settings.
			end
			if ZO_FocusedQuestTrackerPanelTimerAnchor and ZO_FocusedQuestTrackerPanelTimerAnchor.SetHidden then
				ZO_FocusedQuestTrackerPanelTimerAnchor:SetHidden(self.svCurrent.hideFocusedQuestTracker)	-- Override default quest timer panel visibility with our save data settings.
			end
			if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_AUTOMATIC_QUEST_TRACKING) ~= self.svCurrent.autoTrackToAddedQuest then
				SetSetting(SETTING_TYPE_UI, UI_SETTING_AUTOMATIC_QUEST_TRACKING, self.svCurrent.autoTrackToAddedQuest and "true" or "false")	-- Override automatic quest tracking with our save data settings.
			end
			if initial then	-- --------------------------------- after login
				-- Check if this is the first login for this character after using this addon.
				if not self.activityLog.apiVersion then
					self.activityLog.apiVersion = self.currentApiVersion
--					self:ShowWelcomeMessageDialog()
				end
				-- Check if this is the first login after api version update since using this addon.
				if self.activityLog.apiVersion < self.currentApiVersion then
					self.LDL:Debug("detected api version up")
				end
			else	-- ----------------------------------------- after reloadui
				self:ValidateActivityLogFormat()
				self:RefreshQuestList()
			end
		else
--			if initial then		-- ----------------------------- after fast travel
--			end
		end
		self:UpdateTrackerPanelVisibility()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_DEACTIVATED, function(event)
		self.activityLog.apiVersion = self.currentApiVersion
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INTERFACE_SETTING_CHANGED, function(event, settingSystemType, settingId)
		if not settingSystemType == SETTING_TYPE_UI then return end
		if settingId == UI_SETTING_SHOW_QUEST_TRACKER then
			local hideDefaultQuestTracker = not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)
			self.svCurrent.hideFocusedQuestTracker = hideDefaultQuestTracker
			if ZO_FocusedQuestTrackerPanelTimerAnchor and ZO_FocusedQuestTrackerPanelTimerAnchor.SetHidden then
				ZO_FocusedQuestTrackerPanelTimerAnchor:SetHidden(hideDefaultQuestTracker)
			end
		elseif settingId == UI_SETTING_AUTOMATIC_QUEST_TRACKING then
			local newValue = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_AUTOMATIC_QUEST_TRACKING)
			self.svCurrent.autoTrackToAddedQuest = newValue
			self:FireCallbacks("AddOnSettingsChanged", "focusedQuestControl")
		end
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_DEAD, function(event)
		self:UpdateTrackerPanelVisibility()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ALIVE, function(event)
		self:UpdateTrackerPanelVisibility()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(event, inCombat)
		if not self.svCurrent.panelBehavior.showInCombat then
			self:UpdateTrackerPanelVisibility()
		end
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_ADDED, function(event, journalIndex, questName, objectiveName)
		self:UpdateTimeStampByIndex(journalIndex)
		self:UpdateFocusedQuestByEvent(event, journalIndex)
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_ADVANCED, function(event, journalIndex, questName, isPushed, isComplete, mainStepChanged, hideAnnouncement)
		self:UpdateTimeStampByIndex(journalIndex)
		self:UpdateFocusedQuestByEvent(event, journalIndex)
		self:RefreshQuestList()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(event, journalIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden, isConditionCompleteStatusChanged, isConditionCompletableBySiblingStatusChanged)
		self:UpdateTimeStampByIndex(journalIndex)
		self:UpdateFocusedQuestByEvent(event, journalIndex)
		self:RefreshQuestList()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED, function(event, journalIndex)
		self:UpdateTimeStampByIndex(journalIndex)
		self:UpdateFocusedQuestByEvent(event, journalIndex)
		self:RefreshQuestList()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_LIST_UPDATED, function(event)
		self:ValidateActivityLogFormat()
		self:CheckUnrecordedQuest()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_OPTIONAL_STEP_ADVANCED, function(event, text)
		self:RefreshQuestList()
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, function(event, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
		self:DeleteTimeStampByIndex(journalIndex)
	end)
	local function QJM_OnQuestsListUpdatedBehindSchedule()
		self:RefreshQuestList()
	end
	QUEST_JOURNAL_MANAGER:RegisterCallback("QuestListUpdated", function()
		zo_callLater(QJM_OnQuestsListUpdatedBehindSchedule, 100)	-- delay 100ms
	end)
end

function CQT:RegisterInteractions()
	self.interactions = self.interactions or {}
	self.interactions["CQT_TOGGLE_TRACKED_QUEST"] = LibCInteraction:RegisterInteraction("CQT_TOGGLE_TRACKED_QUEST", {
		type = "hold", 
		enabled = function()
			return self.trackerPanel:GetFragment():IsShowing()
		end, 
		keyDownCallback = function(interaction, sourceKeybindName)
			interaction.forceReverse = sourceKeybindName == "CQT_ASSIST_PREVIOUS_TRACKED_QUEST"
		end, 
		holdTime = 300, 
		endedCallback = function()
			self.questTooltip:HideQuestTooltip()
		end, 
		performedCallback = function()
			if self.svCurrent.holdToShowQuestTooltip then
				if not IsInGamepadPreferredMode() or not self:WasBlacklistedHoldKeyBound() then
					local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
					if focusedQuestIndex then
						self.questTooltip:ShowQuestTooltip(focusedQuestIndex, GuiRoot, CENTER, 0, 0, CENTER)
					end
				end
			end
		end, 
		canceledCallback = function(interaction)
			local isModifierKeyDown = interaction.forceReverse or interaction:IsModifierKeyDown(self.svCurrent.cycleBackwardsMod1) or interaction:IsModifierKeyDown(self.svCurrent.cycleBackwardsMod2)
			if self.svCurrent.cycleAllQuests then
				if isModifierKeyDown then
					self:AssistPrevious()
				else
					self:AssistNext()
				end
			else
				if isModifierKeyDown then
					self:ToggleFocusedQuestToPreviousInTheDisplayed()
				else
					self:ToggleFocusedQuestToNextInTheDisplayed()
				end
			end
		end, 
	})
end

function CQT:CopyKeybinds(sourceActionName, destActionName)
	local layer, category, action = GetActionIndicesFromName(destActionName)
	if layer and category and action then
		if IsProtectedFunction("UnbindAllKeysFromAction") then
			CallSecureProtected("UnbindAllKeysFromAction", layer, category, action)
		elseif not IsPrivateFunction("UnbindAllKeysFromAction") then
			UnbindAllKeysFromAction(layer, category, action)
		end
	else
		return
	end
	layer, category, action = GetActionIndicesFromName(sourceActionName)
	if layer and category and action then
		for i = 1, GetMaxBindingsPerAction() do
			local key, mod1, mod2, mod3, mod4 = GetActionBindingInfo(layer, category, action, i)
			CreateDefaultActionBind(destActionName, key, mod1, mod2, mod3, mod4)
		end
	else
		return
	end
	if self.keybinds then
		self.keybinds[sourceActionName] = destActionName
	end
	return true
end

function CQT:UpdateBlacklistedHoldKeys()
-- Since the gamepad key codes are divided between press and hold, unintended collisions can occur between the hold interaction of the press key and the key bindings of the same hold key.
-- Therefore, the status of gamepad hold key settings must be monitored with the goal of avoiding both interactions occurring at the same time.
-- NOTE: At this time, the key bindings of CQT_ASSIST_PREVIOUS_TRACKED_QUEST is not considered.
	ZO_ClearTable(self.blacklistedHoldKeys)
	local layer, category, action = GetActionIndicesFromName("ASSIST_NEXT_TRACKED_QUEST")
	if layer and category and action then
		for i = 1, GetMaxBindingsPerAction() do
			local key = GetActionBindingInfo(layer, category, action, i)
			if IsKeyCodeGamepadKey(key) and not IsKeyCodeHoldKey(key) then
				local holdKey = ConvertKeyPressToHold(key)
				if holdKey ~= KEY_INVALID then
					table.insert(self.blacklistedHoldKeys, holdKey)
				end
			end
		end
	end
end

function CQT:WasBlacklistedHoldKeyBound()
	local wasBound = false
	local layerName = L(SI_KEYBINDINGS_LAYER_GENERAL)
	for _, key in ipairs(self.blacklistedHoldKeys) do
		if GetActionNameFromKey(layerName, key) ~= "" then
			wasBound = true
			break
		end
	end
	return wasBound
end

function CQT:InitializeKeybinds()
	self.keybinds = self.keybinds or {}
	self.blacklistedHoldKeys = self.blacklistedHoldKeys or {}
	self:CopyKeybinds("ASSIST_NEXT_TRACKED_QUEST", "CQT_TOGGLE_TRACKED_QUEST")
	self:UpdateBlacklistedHoldKeys()
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_KEYBINDING_CLEARED, function(event, layerIndex, categoryIndex, actionIndex, bindingIndex)
		local actionName = GetActionInfo(layerIndex, categoryIndex, actionIndex)
		if self.keybinds[actionName] then
			self:CopyKeybinds(actionName, self.keybinds[actionName])	-- Rebuild due to setting changes
		end
		if actionName == "ASSIST_NEXT_TRACKED_QUEST" then
			self:UpdateBlacklistedHoldKeys()
		end
	end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_KEYBINDING_SET, function(event, layerIndex, categoryIndex, actionIndex, bindingIndex)
		local actionName = GetActionInfo(layerIndex, categoryIndex, actionIndex)
		if self.keybinds[actionName] then
			self:CopyKeybinds(actionName, self.keybinds[actionName])	-- Rebuild due to setting changes
		end
		if actionName == "ASSIST_NEXT_TRACKED_QUEST" then
			self:UpdateBlacklistedHoldKeys()
		end
	end)
end


function CQT:InitializeFocusedQuestControlTable()
	ZO_ClearTable(self.forceAssistControl)
	if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.ForceAssist then
		if EVENT_QUEST_ADDED then
			self.forceAssistControl[EVENT_QUEST_ADDED] = self.svCurrent.autoTrackToAddedQuest
		end
		if EVENT_QUEST_ADVANCED then
			self.forceAssistControl[EVENT_QUEST_ADVANCED] = self.svCurrent.autoTrackToProgressedQuest
		end
		if EVENT_QUEST_CONDITION_COUNTER_CHANGED then
			self.forceAssistControl[EVENT_QUEST_CONDITION_COUNTER_CHANGED] = self.svCurrent.autoTrackToProgressedQuest
		end
	end
end

function CQT:UpdateFocusedQuestByEvent(event, journalIndex)
	if self.forceAssistControl[event] then
		FOCUSED_QUEST_TRACKER:ForceAssist(journalIndex)
		if FOCUSED_QUEST_TRACKER.UpdateAssistedVisibility then
			FOCUSED_QUEST_TRACKER:UpdateAssistedVisibility()
		end
	end
end

function CQT:PlayQuestFocusedSound()
	if not FOCUSED_QUEST_TRACKER.disableAudio then
		PlaySound(CQT_SOUNDS.FOCUSED)
	end
end

function CQT:ToggleFocusedQuestToNextInTheDisplayed()
-- Toggle focused quest to the next quest in the displayed.
	local numQuestList = #self.questList
	if numQuestList == 0 then return end
	local nextJournalIndex
	local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	local wasZoneStoryAssisted = IsZoneStoryAssisted()		-- Whether a zone guide is displayed on the HUD tracker
	local wasAssistedQuestDisplayed = self.circularJournalIndexList[focusedQuestIndex] ~= nil
	local topQuestIndex = self.questList[1].journalIndex	-- quest index of the tracked quest shown at the top of the tracker panel.
	if wasAssistedQuestDisplayed then
		nextJournalIndex = self.circularJournalIndexList[focusedQuestIndex].nextJournalIndex
	else
		nextJournalIndex = topQuestIndex
	end
	if wasZoneStoryAssisted then
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(false)
		if self.svCurrent.cycleZoneGuide and nextJournalIndex ~= topQuestIndex then
			-- If the zone guide was displayed in reverse rotation, it is natural to just turn off the zone guide and do nothing.
			self:PlayQuestFocusedSound()
			return
		end
	end
	if self.svCurrent.cycleZoneGuide and wasAssistedQuestDisplayed and nextJournalIndex == topQuestIndex and IsZoneStoryTracked() and not wasZoneStoryAssisted then
		-- Attempts to display the zone guide only when the focused quest is the bottom quest of our tracker panel and a zone guide is not displayed on the HUD tracker.
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(true)
		self:PlayQuestFocusedSound()
	else
		FOCUSED_QUEST_TRACKER:ForceAssist(nextJournalIndex)
	end
end

function CQT:ToggleFocusedQuestToPreviousInTheDisplayed()
	local numQuestList = #self.questList
	if numQuestList == 0 then return end
	local previousJournalIndex
	local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	local wasZoneStoryAssisted = IsZoneStoryAssisted()		-- Whether a zone guide is displayed on the HUD tracker
	local wasAssistedQuestDisplayed = self.circularJournalIndexList[focusedQuestIndex] ~= nil
	local bottomQuestIndex = self.questList[numQuestList].journalIndex	-- quest index of the tracked quest shown at the bottom of the tracker panel.
	if wasAssistedQuestDisplayed then
		previousJournalIndex = self.circularJournalIndexList[focusedQuestIndex].prevJournalIndex
	else
		previousJournalIndex = self.questList[1].journalIndex
	end
	if wasZoneStoryAssisted then
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(false)
		if self.svCurrent.cycleZoneGuide and previousJournalIndex ~= bottomQuestIndex then
			-- If the zone guide was displayed in reverse rotation, it is natural to just turn off the zone guide and do nothing.
			self:PlayQuestFocusedSound()
			return
		end
	end
	if self.svCurrent.cycleZoneGuide and wasAssistedQuestDisplayed and previousJournalIndex == bottomQuestIndex and IsZoneStoryTracked() and not wasZoneStoryAssisted then
		-- Attempts to display the zone guide only when the focused quest is the top quest of our tracker panel and a zone guide is not displayed on the HUD tracker.
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(true)
		self:PlayQuestFocusedSound()
	else
		FOCUSED_QUEST_TRACKER:ForceAssist(previousJournalIndex)
	end
end

function CQT:AssistNext()
-- Toggle focused quest to the next in the QJM sorted quest list.
	local questList = QUEST_JOURNAL_MANAGER:GetQuestList()
	local numQuestList = #questList
	if numQuestList == 0 then return end
	local nextJournalIndex
	local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	local wasZoneStoryAssisted = IsZoneStoryAssisted()		-- Whether a zone guide is displayed on the HUD tracker
	for i, quest in ipairs(questList) do
		if quest.questIndex == focusedQuestIndex then
			nextJournalIndex = (i == numQuestList) and 1 or (i + 1)
			break
		end
	end
	if wasZoneStoryAssisted then
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(false)
		if self.svCurrent.cycleZoneGuide and nextJournalIndex ~= 1 then
			-- If the zone guide was displayed in reverse rotation, it is natural to just turn off the zone guide and do nothing.
			self:PlayQuestFocusedSound()
			return
		end
	end
	if self.svCurrent.cycleZoneGuide and nextJournalIndex == 1 and IsZoneStoryTracked() and not wasZoneStoryAssisted then
		-- Attempts to display the zone guide only when the focused quest is the last quest in the QJM sorted list and a zone guide is not displayed on the HUD tracker.
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(true)
		self:PlayQuestFocusedSound()
	else
		FOCUSED_QUEST_TRACKER:ForceAssist(questList[nextJournalIndex].questIndex)
	end
end

function CQT:AssistPrevious()
-- Toggle focused quest to the previous in the QJM sorted quest list. oppositte of the CQT:AssistNext().
	local questList = QUEST_JOURNAL_MANAGER:GetQuestList()
	local numQuestList = #questList
	if numQuestList == 0 then return end
	local previousJournalIndex
	local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	local wasZoneStoryAssisted = IsZoneStoryAssisted()		-- Whether a zone guide is displayed on the HUD tracker
	for i, quest in ipairs(questList) do
		if quest.questIndex == focusedQuestIndex then
			previousJournalIndex = (i == 1) and numQuestList or (i - 1)
			break
		end
	end
	if wasZoneStoryAssisted then
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(false)
		if self.svCurrent.cycleZoneGuide and previousJournalIndex ~= numQuestList then
			-- If the zone guide was displayed in reverse rotation, it is natural to just turn off the zone guide and do nothing.
			self:PlayQuestFocusedSound()
			return
		end
	end
	if self.svCurrent.cycleZoneGuide and previousJournalIndex == numQuestList and IsZoneStoryTracked() and not wasZoneStoryAssisted then
		-- Attempts to display the zone guide only when the focused quest is the first quest in the QJM sorted list and a zone guide is not displayed on the HUD tracker.
		ZO_ZoneStories_Manager.SetTrackedZoneStoryAssisted(true)
		self:PlayQuestFocusedSound()
	else
		FOCUSED_QUEST_TRACKER:ForceAssist(questList[previousJournalIndex].questIndex)
	end
end

function CQT:RefreshQuestList()
	local quests = QUEST_JOURNAL_MANAGER:GetQuestList()
	local pinnedQuestList = {}
	local unpinnedQuestList = {}
	local numEntry = 0
	ZO_ClearNumericallyIndexedTable(self.questList)
	for k, v in pairs(quests) do
		local questId = GetQuestId(v.questIndex)
		local t = {
			journalIndex = v.questIndex, 
			qjmQuestIndex = k, 
			questId = questId, 
			timestamp = self:GetTimeStamp(questId) or self.sessionStartTime, 
			timer = self.questTimer:GetTimer(v.questIndex)
		}
		if not self:IsIgnoredQuest(questId) and not self:IsUnrecordedQuest(questId) then
			if self:IsPinnedQuest(questId) then
				table.insert(pinnedQuestList, t)
			else
				table.insert(unpinnedQuestList, t)
			end
		end
	end
	
	table.sort(pinnedQuestList, function(a, b)
		if a.timestamp[3] ~= b.timestamp[3] then
			return a.timestamp[3] < b.timestamp[3]
		else	
			return a.questId < b.questId
		end
	end)
	table.sort(unpinnedQuestList, function(a, b)
		if a.timestamp[1] ~= b.timestamp[1] then
			return a.timestamp[1] > b.timestamp[1]
		elseif a.timestamp[2] ~= b.timestamp[2] then
			return a.timestamp[2] > b.timestamp[2]
		else	
			return a.questId < b.questId
		end
	end)
	
	for _, v in ipairs(pinnedQuestList) do
		if numEntry >= self.svCurrent.maxNumDisplay then break end
		if numEntry >= self.svCurrent.maxNumPinnedQuest then break end
		table.insert(self.questList, v)
		numEntry = numEntry + 1
	end
	for _, v in ipairs(unpinnedQuestList) do
		if numEntry >= self.svCurrent.maxNumDisplay then break end
		table.insert(self.questList, v)
		numEntry = numEntry + 1
	end

	ZO_ClearTable(self.circularJournalIndexList)
	local numQuestListEntry = #self.questList
	if numQuestListEntry > 0 then
		local prevIndex = self.questList[numQuestListEntry].journalIndex
		for k, v in ipairs(self.questList) do
			local t = {
				questListIndex = k, 
				prevJournalIndex = prevIndex, 
			}
			self.circularJournalIndexList[v.journalIndex] = t
			if self.circularJournalIndexList[prevIndex] then
				self.circularJournalIndexList[prevIndex].nextJournalIndex = v.journalIndex
			end
			prevIndex = v.journalIndex
		end
		self.circularJournalIndexList[prevIndex].nextJournalIndex = self.questList[1].journalIndex
	end
	self:FireCallbacks("TrackerPanelQuestListUpdated", self.questList)
end


function CQT:IsTrackedQuestByIndex(journalIndex)
-- Returns whether or not the quest is being tracked by CQuestTracker
	return self.trackerPanel:IsTrackedQuestByIndex(journalIndex)
end
function CQT:IsTrackedQuest(questId)
	-- TODO: should use self.masterQuestList instead
	local foundIndex
	for _, v in ipairs(self.questList) do
		if v.questId == questId then
			foundIndex = v.journalIndex
			break
		end
	end
	return foundIndex and self:IsTrackedQuestByIndex(foundIndex) or false
end

function CQT:PickOutQuestByIndex(journalIndex, suppressSound)
	return self:PickOutQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:PickOutQuest(questId, suppressSound)
	self:UpdateTimeStamp(questId)
	if not suppressSound then
		PlaySound(CQT_SOUNDS.PICK_OUT)
	end
	self:RefreshQuestList()
end

function CQT:PickOutPinnedQuestByIndex(journalIndex, suppressSound)
	return self:PickOutPinnedQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:PickOutPinnedQuest(questId, suppressSound)
	self:UpdateTimeStamp(questId)
	if not suppressSound then
		PlaySound(CQT_SOUNDS.PICK_OUT)
	end
	self:SetPinnedStatusTimeStamp(questId)
	self:RefreshQuestList()
end

function CQT:RuleOutQuestByIndex(journalIndex, suppressSound)
	return self:RuleOutQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:RuleOutQuest(questId, suppressSound)
	self:UpdateTimeStamp(questId, 0 - GetTimeStamp(), 0 - GetGameTimeMilliseconds())
	if not suppressSound then
		PlaySound(CQT_SOUNDS.RULE_OUT)
	end
	if self:IsPinnedQuest(questId) then
		self:ResetPinnedStatusTimeStamp(questId)
	end
	self:RefreshQuestList()
end

function CQT:EnablePinningQuestByIndex(journalIndex, suppressSound)
	return self:EnablePinningQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:EnablePinningQuest(questId, suppressSound)
	if self:IsUnrecordedQuest(questId) then
		self:UpdateTimeStamp(questId)
	end
	if not suppressSound then
		PlaySound(CQT_SOUNDS.ENABLE_PINNING)
	end
	self:SetPinnedStatusTimeStamp(questId)
	self:RefreshQuestList()
end

function CQT:DisablePinningQuestByIndex(journalIndex, suppressSound)
	return self:DisablePinningQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:DisablePinningQuest(questId, suppressSound)
	if not suppressSound then
		PlaySound(CQT_SOUNDS.DISABLE_PINNING)
	end
	self:ResetPinnedStatusTimeStamp(questId)
	self:RefreshQuestList()
end

function CQT:IsPinnedQuestByIndex(journalIndex)
	return self:IsPinnedQuest(GetQuestId(journalIndex))
end
function CQT:IsPinnedQuest(questId)
	return self.activityLog.quest[questId] and self.activityLog.quest[questId][3] and self.activityLog.quest[questId][3] > 0
end

function CQT:EnableIgnoringQuestByIndex(journalIndex, suppressSound)
	return self:EnableIgnoringQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:EnableIgnoringQuest(questId, suppressSound)
	if self:IsUnrecordedQuest(questId) then
		self:UpdateTimeStamp(questId, 0 - GetTimeStamp(), 0 - GetGameTimeMilliseconds())
	end
	if not suppressSound then
		PlaySound(CQT_SOUNDS.ENABLE_IGNORING)
	end
	self:SetPinnedStatusTimeStamp(questId, 0 - GetTimeStamp())
	self:RefreshQuestList()
end

function CQT:DisableIgnoringQuestByIndex(journalIndex, suppressSound)
	return self:DisableIgnoringQuest(GetQuestId(journalIndex), suppressSound)
end
function CQT:DisableIgnoringQuest(questId, suppressSound)
	if not suppressSound then
		PlaySound(CQT_SOUNDS.DISABLE_IGNORING)
	end
	self:ResetPinnedStatusTimeStamp(questId)
	self:RefreshQuestList()
end

function CQT:IsIgnoredQuestByIndex(journalIndex)
	return self:IsIgnoredQuest(GetQuestId(journalIndex))
end
function CQT:IsIgnoredQuest(questId)
	return self.activityLog.quest[questId] and self.activityLog.quest[questId][3] and self.activityLog.quest[questId][3] < 0
end

function CQT:IsUnrecordedQuestByIndex(journalIndex)
	return self:IsUnrecordedQuest(GetQuestId(journalIndex))
end
function CQT:IsUnrecordedQuest(questId)
	return self:IsValidTimeStamp(questId) and self.activityLog.quest[questId][1] == 0 and self.activityLog.quest[questId][2] == 0
end


function CQT:IsValidTimeStamp(questId)
	return self.activityLog.quest[questId] and self.activityLog.quest[questId][1] and self.activityLog.quest[questId][2]
end

function CQT:UpdateTimeStampByIndex(journalIndex, arg1, arg2)
	return self:UpdateTimeStamp(GetQuestId(journalIndex), arg1, arg2)
end
function CQT:UpdateTimeStamp(questId, arg1, arg2)
	self.trackerPanel:SetTreeNodeOpenStatus(questId, nil)	-- clear previous status
	if not self.activityLog.quest[questId] then
		self.activityLog.quest[questId] = {}
	end
	self.activityLog.quest[questId][1] = arg1 or GetTimeStamp()
	self.activityLog.quest[questId][2] = arg2 or GetGameTimeMilliseconds()
end

function CQT:SetPinnedStatusTimeStampByIndex(journalIndex, arg3)
	return self:SetPinnedStatusTimeStamp(GetQuestId(journalIndex), arg3)
end
function CQT:SetPinnedStatusTimeStamp(questId, arg3)
	self.trackerPanel:SetTreeNodeOpenStatus(questId, nil)	-- clear previous status
	if self.activityLog.quest[questId] then
		self.activityLog.quest[questId][3] = arg3 or GetTimeStamp()
	end
end

function CQT:ResetPinnedStatusTimeStampByIndex(journalIndex)
	return self:ResetPinnedStatusTimeStamp(GetQuestId(journalIndex))
end
function CQT:ResetPinnedStatusTimeStamp(questId)
	self.trackerPanel:SetTreeNodeOpenStatus(questId, nil)	-- clear previous status
	if self.activityLog.quest[questId] then
		self.activityLog.quest[questId][3] = nil
	end
end

function CQT:DeleteTimeStampByIndex(journalIndex)
	return self:DeleteTimeStamp(GetQuestId(journalIndex))
end
function CQT:DeleteTimeStamp(questId)
	self.trackerPanel:SetTreeNodeOpenStatus(questId, nil)	-- clear previous status
	if self.activityLog.quest[questId] then
		self.activityLog.quest[questId] = nil
	end
end

function CQT:CopyTimeStamp(srcQuestId, destQuestId)
	if self.activityLog.quest[srcQuestId] then
		self.trackerPanel:SetTreeNodeOpenStatus(destQuestId, self.trackerPanel:GetTreeNodeOpenStatus(srcQuestId))	-- copy tree node status
		self.activityLog.quest[destQuestId] = {}
		ZO_ShallowTableCopy(self.activityLog.quest[srcQuestId], self.activityLog.quest[destQuestId])
	end
end


function CQT:GetTimeStampByIndex(journalIndex)
	return self.activityLog[GetQuestId(journalIndex)]
end
function CQT:GetTimeStamp(questId)
	return self.activityLog.quest[questId]
end

function CQT:CheckUnrecordedQuest()
	for i = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then
			local questId = GetQuestId(i)
			if not self:IsValidTimeStamp(questId) then
				-- If the player had accepted an unrecorded quest in the activity log.
				if select(7, GetJournalQuestInfo(i)) then
					self:UpdateTimeStamp(questId, nil, i)
				else
					self:UpdateTimeStamp(questId, 0, 0)
				end
			end
		end
	end
end

function CQT:ValidateActivityLogFormat()
-- validate and convert activity log format if needed.
	if self.activityLog.format == self.activityLogVersion then return end

	-- check to see if the save data is new.
	if self.activityLog.format == nil then
		if next(self.activityLog.quest) then
			self.LDL:Debug("Detected: quest activity log entry")
			self.activityLog.format = 1		-- at least one entry found in the activity log means previous format version 1.
		else
			self.LDL:Debug("Detected: new save data")
			self.activityLog.format = self.activityLogVersion
		end
	end

	-- convert format version to 2 if needed.
	if self.activityLog.format == nil or self.activityLog.format < 2 then
		self.LDL:Debug("Detected: quest activity log format v1")
		if self.activityLog.quest[0] then
			self.LDL:Debug("Detected: quest activity log id 0")
			-- fixed the questId zero issue
			local invalidQuests = {
				[5342] = true, -- Planemeld Obverse
				[5431] = true, -- Pledge: White-Gold Tower
				[5136] = true, -- Summary Execution
				[5382] = true, -- Pledge: Imperial City Prison
			}
			local offset = 0
			for qId in pairs(invalidQuests) do
				if HasQuest(qId) then
					self:CopyTimeStamp(0, qId)
					-- Added an offset to the timestamp if you have more than one eligible quest.
					self.activityLog.quest[qId][2] = self.activityLog.quest[qId][2] + offset
					self.LDL:Debug("Copied: quest activity log ID 0 -> ID %s", tostring(qId))
					offset = offset + 1
				end
			end
			self:DeleteTimeStamp(0)
			self.LDL:Debug("Deleted: quest activity log ID 0")
		end
		for i = 1, MAX_JOURNAL_QUESTS do
			if IsValidQuestIndex(i) then
				local qId = GetQuestId(i)
				local mainId = GetQuestMainId(i)
				if qId ~= 0 and mainId ~= 0 and qId ~= mainId then
					if self.activityLog.quest[mainId] then
						self:CopyTimeStamp(mainId, qId)
						self.LDL:Debug("Copied: quest activity log ID %s -> ID %s", tostring(mainId), tostring(qId))
						self:DeleteTimeStamp(mainId)
						self.LDL:Debug("Deleted: quest activity log ID %s", tostring(mainId))
					end
				end
			end
		end
		self.activityLog.format = 2
	end
end


function CQT:ShowQuestListManagementMenu(owner, initialRefCount, menuType)
	local PADDING = 200
	local function QuestListMenuTooltip(control, inside, journalIndex)
		if inside then
			self.questTooltip:ShowQuestTooltipNextToControl(journalIndex, ZO_Menu, 200)
		else
			self.questTooltip:HideQuestTooltip()
		end
	end
	local quests = QUEST_JOURNAL_MANAGER:GetQuestList()
	if quests and #quests > 0 then
		ClearMenu()
		AddCustomMenuItem(zo_strformat(L(SI_CQT_QUESTLIST_MENU_HEADER), GetNumJournalQuests(), MAX_JOURNAL_QUESTS), function() end, MENU_ADD_OPTION_HEADER)
		for k, v in pairs(quests) do
			local format
			local subMenuEntries = {}
--[[
			table.insert(subMenuEntries, {
				label = L(SI_CQT_PICK_OUT_QUEST), 
				callback = function()
					self:PickOutQuestByIndex(v.questIndex)
				end, 
				disabled = function()
					return self:IsIgnoredQuestByIndex(v.questIndex) or self:IsPinnedQuestByIndex(v.questIndex)
				end, 
				tooltip = function(control, inside)
					QuestListMenuTooltip(control, inside, v.questIndex)
				end, 
			})
]]
			if self:IsPinnedQuestByIndex(v.questIndex) then
				format = L(SI_CQT_QUEST_LIST_PINNED_FORMATTER)
				table.insert(subMenuEntries, {
					label = L(SI_CQT_DISABLE_PINNING_QUEST), 
					callback = function()
						self:DisablePinningQuestByIndex(v.questIndex)
					end, 
					tooltip = function(control, inside)
						QuestListMenuTooltip(control, inside, v.questIndex)
					end, 
				})
			else
				table.insert(subMenuEntries, {
					label = L(SI_CQT_ENABLE_PINNING_QUEST), 
					callback = function()
						self:EnablePinningQuestByIndex(v.questIndex)
					end, 
					tooltip = function(control, inside)
						QuestListMenuTooltip(control, inside, v.questIndex)
					end, 
				})
			end
			if self:IsIgnoredQuestByIndex(v.questIndex) then
				format = L(SI_CQT_QUEST_LIST_IGNORED_FORMATTER)
				table.insert(subMenuEntries, {
					label = L(SI_CQT_DISABLE_IGNORING_QUEST), 
					callback = function()
						self:DisableIgnoringQuestByIndex(v.questIndex)
					end, 
					tooltip = function(control, inside)
						QuestListMenuTooltip(control, inside, v.questIndex)
					end, 
				})
			else
				format = format or L(SI_CQT_QUEST_LIST_NORMAL_FORMATTER)
				table.insert(subMenuEntries, {
					label = L(SI_CQT_ENABLE_IGNORING_QUEST), 
					callback = function()
						self:EnableIgnoringQuestByIndex(v.questIndex)
					end, 
					tooltip = function(control, inside)
						QuestListMenuTooltip(control, inside, v.questIndex)
					end, 
				})
			end
			table.insert(subMenuEntries, {
				label = L(SI_CQT_MOST_LOWER_QUEST), 
				callback = function()
					self:RuleOutQuestByIndex(v.questIndex)
				end, 
				tooltip = function(control, inside)
					QuestListMenuTooltip(control, inside, v.questIndex)
				end, 
			})
			if GetJournalQuestType(v.questIndex) ~= QUEST_TYPE_MAIN_STORY then
				table.insert(subMenuEntries, {
					label = L(SI_QUEST_TRACKER_MENU_ABANDON), 
					callback = function()
						AbandonQuest(v.questIndex)
			 		end, 
					disabled = function()
						return GetJournalQuestType(v.questIndex) == QUEST_TYPE_MAIN_STORY
					end, 
					tooltip = function(control, inside)
						QuestListMenuTooltip(control, inside, v.questIndex)
					end, 
				})
			end
			AddCustomSubMenuItem(zo_strformat(format, v.name), subMenuEntries, nil, nil, nil, nil, function()
				self.questTooltip:HideQuestTooltip()
				self:PickOutQuestByIndex(v.questIndex)
			end)
			AddCustomMenuTooltip(function(control, inside)
				QuestListMenuTooltip(control, inside, v.questIndex)
			end)
		end
		ShowMenu(owner, initialRefCount, menuType)
	end
end

function CQT:ShowQuestPingOnMap(journalIndex, stepIndex, conditionIndex)
	local result = nil
	journalIndex = journalIndex or 0
	if self.svCurrent.qPingAttributes.pingingEnabled then
		if self.questPingManager then
			if not self.questPingManager:IsShowingQuestPingPins(journalIndex) then
				self.questPingManager:SetWorldMapQuestPingPins(journalIndex)
			end
		end
		if CQT_WORLD_MAP_UTILITY then
			result = CQT_WORLD_MAP_UTILITY:ShowQuestOnMap(journalIndex, stepIndex, conditionIndex)
			self.LDL:Debug("ShowQuestOnMap: result=%s", tostring(result))
		end
	end
	return result
end

function CQT:AddTrackerPanelFragmentToGameMenuScene()
	if self.trackerPanel then
		local trackerPanelFragment= self.trackerPanel:GetFragment()
		local trackerPanelTitleBarFragment = self.trackerPanel:GetTitleBarFragment()
		if not GAME_MENU_SCENE:HasFragment(trackerPanelFragment) then
			GAME_MENU_SCENE:AddFragment(trackerPanelFragment)
		end
		if not GAME_MENU_SCENE:HasFragment(trackerPanelTitleBarFragment) then
			GAME_MENU_SCENE:AddFragment(trackerPanelTitleBarFragment)
		end
		
	end
end

function CQT:RemoveTrackerPanelFragmentFromGameMenuScene()
	if self.trackerPanel then
		local trackerPanelFragment= self.trackerPanel:GetFragment()
		local trackerPanelTitleBarFragment = self.trackerPanel:GetTitleBarFragment()
		if GAME_MENU_SCENE:HasFragment(trackerPanelFragment) then
			GAME_MENU_SCENE:RemoveFragment(trackerPanelFragment)
		end
		if GAME_MENU_SCENE:HasFragment(trackerPanelTitleBarFragment) then
			GAME_MENU_SCENE:RemoveFragment(trackerPanelTitleBarFragment)
		end
	end
end

function CQT:UpdateTrackerPanelVisibility()
	if self.trackerPanel then
		local trackerPanelFragment= self.trackerPanel:GetFragment()
		local trackerPanelTitleBarFragment = self.trackerPanel:GetTitleBarFragment()
		trackerPanelFragment:SetHiddenForReason("DisabledInCombat", (not self.svCurrent.panelBehavior.showInCombat) and IsUnitInCombat("player"), 0, 0)
		trackerPanelFragment:SetHiddenForReason("DisabledInBattlegrounds", (not self.svCurrent.panelBehavior.showInBattleground) and IsActiveWorldBattleground(), 0, 0)
		trackerPanelFragment:SetHiddenForReason("DisabledWhileKeybindingsSettings", KEYBINDINGS_FRAGMENT:IsShowing(), 0, 0)
		trackerPanelFragment:SetHiddenForReason("DisabledBySetting", self.svCurrent.hideCQuestTracker, 0, 0)
		trackerPanelFragment:SetHiddenForReason("DisabledWhenDead", IsUnitDead("player"), 0, 0)
		trackerPanelFragment:SetHiddenForReason("DisabledInGameMenuScene", (not self.svCurrent.panelBehavior.showInGameMenuScene) and GAME_MENU_SCENE:IsShowing(), 0, 0)
		trackerPanelTitleBarFragment:SetHiddenForReason("DisabledInGameMenuScene", (not self.svCurrent.panelBehavior.showInGameMenuScene) and GAME_MENU_SCENE:IsShowing(), 0, 0)
	end
end

function CQT:ShowWelcomeMessageDialog()
	ZO_Dialogs_ShowDialog(self.name .. "_WELCOME_MESSAGE")
end

function CQT:OnAddOnSettingsChanged(settingCategories)
	if not settingCategories then
		return
	end
	if settingCategories == "maxNumDisplay" then
		self:RefreshQuestList()
		return
	end
	if settingCategories == "compactMode" then
		self.trackerPanel:ClearAllTreeNodeOpenStatus()
		return
	end
	if settingCategories == "improveKeybinds" then
		if self.svCurrent.improveKeybinds then
			PushActionLayerByName("CQT_InteractionSnatcher")
		else
			RemoveActionLayerByName("CQT_InteractionSnatcher")
		end
		return
	end
	if settingCategories == "focusedQuestControl" then
		self:InitializeFocusedQuestControlTable()
		return
	end
	if settingCategories == "questPing" then
		if self.questPingManager then
			self.questPingManager:RefreshWorldMapQuestPings()
			return
		end
	end
end

function CQT:RegisterSharedAPI()
--
-- ---- CQT shared API Reference
--
-- * CQT:IsTrackedQuestByIndex(journalIndex)
-- ** _Returns:_ *bool* _isTracked_
	self._shared.IsTrackedQuestByIndex = function(_, journalIndex)
		return self:IsTrackedQuestByIndex(journalIndex)
	end

-- * CQT:PickOutQuestByIndex(journalIndex, suppressSound)
	self._shared.PickOutQuestByIndex = function(_, journalIndex, suppressSound)
		return self:PickOutQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:RuleOutQuestByIndex(journalIndex, suppressSound)
	self._shared.RuleOutQuestByIndex = function(_, journalIndex, suppressSound)
		return self:RuleOutQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:EnablePinningQuestByIndex(journalIndex, suppressSound)
	self._shared.EnablePinningQuestByIndex = function(_, journalIndex, suppressSound)
		return self:EnablePinningQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:DisablePinningQuestByIndex(journalIndex, suppressSound)
	self._shared.DisablePinningQuestByIndex = function(_, journalIndex, suppressSound)
		return self:DisablePinningQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:IsPinnedQuestByIndex(journalIndex)
-- ** _Returns:_ *bool* _isPinned_
	self._shared.IsPinnedQuestByIndex = function(_, journalIndex)
		return self:IsPinnedQuestByIndex(journalIndex)
	end

-- * CQT:EnableIgnoringQuestByIndex(journalIndex, suppressSound)
	self._shared.EnableIgnoringQuestByIndex = function(_, journalIndex, suppressSound)
		return self:EnableIgnoringQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:DisableIgnoringQuestByIndex(journalIndex, suppressSound)
	self._shared.DisableIgnoringQuestByIndex = function(_, journalIndex, suppressSound)
		return self:DisableIgnoringQuestByIndex(journalIndex, suppressSound)
	end

-- * CQT:IsIgnoredQuestByIndex(journalIndex)
-- ** _Returns:_ *bool* _isIgnored_
	self._shared.IsIgnoredQuestByIndex = function(_, journalIndex)
		return self:IsIgnoredQuestByIndex(journalIndex)
	end

-- * CQT:AssistNext()
	self._shared.AssistNext = function()
		return self:AssistNext()
	end

-- * CQT:AssistPrevious()
	self._shared.AssistPrevious = function()
		return self:AssistPrevious()
	end

-- * CQT:ShowQuestPingOnMap(journalIndex, stepIndex, conditionIndex)
-- ** _Returns:_ *[SetMapResultCode|#SetMapResultCode]:nilable* _setMapResult_
-- **  NOTE: A return value of nil means finished without displaying the map.
	self._shared.ShowQuestPingOnMap = function(_, journalIndex, stepIndex, conditionIndex)
		return self:ShowQuestPingOnMap(journalIndex, stepIndex, conditionIndex)
	end
end

-- ---------------------------------------------------------------------------------------
-- XML Handlers
-- ---------------------------------------------------------------------------------------
-- For when you want to propagate to the parent node control without breaking self out of the args
-- CQT_PropagateHandlerToParentNode("OnMouseUp", ...)
function CQT_PropagateHandlerToParentNode(handlerName, control, ...)
	if control and control.node and control.node:GetParent() then
		local parentNodeControl = control.node:GetParent():GetControl()
		if parentNodeControl and parentNodeControl[handlerName] then
			parentNodeControl[handlerName](parentNodeControl, ...)
		end
	end
end
CQT:RegisterGlobalObject("CQT_PropagateHandlerToParentNode", CQT_PropagateHandlerToParentNode)

function CQT_QuestListButton_OnClicked(control, button)
	if button == MOUSE_BUTTON_INDEX_LEFT then
		CQT:ShowQuestListManagementMenu(control)
	end
end
CQT:RegisterGlobalObject("CQT_QuestListButton_OnClicked", CQT_QuestListButton_OnClicked)

function CQT_SettingButton_OnClicked(control, button)
	if button == MOUSE_BUTTON_INDEX_LEFT then
		CQT.settingPanel:OpenSettingPanel()
	end
end
CQT:RegisterGlobalObject("CQT_SettingButton_OnClicked", CQT_SettingButton_OnClicked)

function CQT_ToggleTrackerPanelVisibility_OnKeybindDown()
	CQT.settingPanel:ToggleTrackerPanelHideSetting()
end
CQT:RegisterGlobalObject("CQT_ToggleTrackerPanelVisibility_OnKeybindDown", CQT_ToggleTrackerPanelVisibility_OnKeybindDown)

function CQT_ShowFocusedQuestOnMap_OnKeybindDown()
	if ZO_WorldMap_IsWorldMapShowing() then
		SCENE_MANAGER:HideCurrentScene()
	else
		local focusedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
		CQT:ShowQuestPingOnMap(focusedQuestIndex)
	end
end
CQT:RegisterGlobalObject("CQT_ShowFocusedQuestOnMap_OnKeybindDown", CQT_ShowFocusedQuestOnMap_OnKeybindDown)

-- ---------------------------------------------------------------------------------------
-- Chat commands
-- ---------------------------------------------------------------------------------------
SLASH_COMMANDS["/cqt.debug"] = function(arg) if arg ~= "" then CQT:ConfigDebug({tonumber(arg)}) end end

