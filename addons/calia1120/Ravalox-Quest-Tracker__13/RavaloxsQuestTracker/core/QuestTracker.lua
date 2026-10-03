
local LQI = RavaloxsQuestTracker_LQI

local DEBUG_MODE 			= true
QUESTTRACKER_DEBUG_TABLE 	= {}

local ADDON_NAME	= "RavaloxsQuestTracker"
local VERSION_CODE	= "3.8.3.4"

local CONSTRAINT_WIDTH = 100
local CONSTRAINT_HEIGHT = 60
-- I cut it close on the right hand border, there is practically no padding
-- If text gets cut off, try changing this, but no more than +5
-- If it takes that much then something is wrong, let me know & I'll look into it.
local TEXT_LABEL_PADDING = 0

local colorYellow 		= "|cFFFF00" 	-- yellow 
local colorSoftYellow   = "|cCCCC00"    -- Duller Yellow for Description
local colorRed 			= "|cFF0000" 	-- Red
local colorRavalox		= "|cB60000"    -- Ravalox Red  -- B6 = Red 182  a brighter 82 red
local colorCMDBlue		= "|c1155bb"    -- Dull blue used to indicate "typable" text
--[[
the game calls forceAssist on more than one quest before a final starting quest is arrived at. This will block us from wasting time selecting & displaying auto-tooltips for those quests until the player is completely activated and all game callbacks have been fired to prevent displaying an auto-tooltip on load, reloadUI, & zoning and from leaving nodes open the user did not open themselves, if they have exclusitivity turned off & the game selects random quests.
--]]
local ALLOW_QUEST_ASSIST_CALLBACK 	= false
local SORT_TYPE_QUEST_CATEGORIES 	= 1
local SORT_TYPE_QUESTS				= 2
local USER_REQUESTED_OPEN 			= true

local QuestTracker 	= ZO_Object:New()

--=====================================================--
--======= DEBUG =========--
--=====================================================--
local function debugMsg(msg, tableItem)
	if not DEBUG_MODE then return end
	
	if msg and msg ~= "" then
		d(msg)
		table.insert(QUESTTRACKER_DEBUG_TABLE, msg)
	end
	
	-- Used to save object references for later examination:
	if tableItem then
		table.insert(QUESTTRACKER_DEBUG_TABLE, tableItem)
	end
end

--=====================================================--
--======= BACKDROP FUNCTIONS =========--
--=====================================================--
local backdrops = {
	[1]	= {name = "None"},
	[2] = {name = "Fancy"},
	[3] = {name = "Colored"},
}
 -- Used in settings menu to populate choices
function QuestTracker:GetBackdropChoices()
	local choices = {}
	for k,v in ipairs(backdrops) do
		choices[#choices+1] = v.name
	end
	return choices
end

--=====================================================--
--======= FONT FUNCTIONS =========--
--=====================================================--
local NodeFonts = {
	[1] = {name = "Bold", 					font = "BOLD_FONT"},
	[2] = {name = "Medium", 				font = "MEDIUM_FONT"},
	[3] = {name = "Chat", 					font = "CHAT_FONT"},
	[4] = {name = "Antique", 				font = "ANTIQUE_FONT"},
	[5] = {name = "Handwritten", 			font = "HANDWRITTEN_FONT"},
	[6] = {name = "Stone Tablet", 			font = "STONE_TABLET_FONT"},
	[7] = {name = "Gamepad Bold", 			font = "GAMEPAD_BOLD_FONT"},
	[8] = {name = "Gamepad Medium", 		font = "GAMEPAD_MEDIUM_FONT"},
--	[9] = {name = "Arial Narrow",   		font = "univers55"},
}
 -- Used in settings menu to populate choices
function QuestTracker:GetFontChoices()
	local choices = {}
	
	for k,v in ipairs(NodeFonts) do
		choices[#choices+1] = v.name
	end
	return choices
end
function QuestTracker:GetFontByName(name)
	for k,v in ipairs(NodeFonts) do
		if v.name == name then
			return v.font
		end
	end
	return "ZoFontHeader"
end

-- Font outline 
local NodeOutlines = {
	[1] = {name = "None"},
	[2] = {name = "Soft Thick Shadow", 	outline = "soft-shadow-thick"},
	[3] = {name = "Soft Thin Shadow", 	outline = "soft-shadow-thin"},
	[4] = {name = "Shadow", 			outline = "shadow"},
}
function QuestTracker:GetOutlineChoices()
	local choices = {}
	
	for k,v in ipairs(NodeOutlines) do
		choices[#choices+1] = v.name
	end
	return choices
end

function QuestTracker:GetOutlineByName(outlineName)
	for k,v in ipairs(NodeOutlines) do
		if v.name == outlineName then
			return v.outline
		end
	end
end


-- font string layout example: "$(BOLD_FONT)|30|soft-shadow-thick"
function QuestTracker:BuildFontString(font, size, outline)
	local fontString = zo_strformat("$(<<1>>)|<<2>>", font,size)
	--
	if outline then
		fontString = zo_strformat("<<1>>|<<2>>", fontString,outline)
	end
	--]]
	return fontString
end

function QuestTracker:GetCategoryFontString()
	local categoryFontSettings 	= self.svCurrent.fontSettings.categories
	local font 					= self:GetFontByName(categoryFontSettings.font)
	local fontOutline 			= self:GetOutlineByName(categoryFontSettings.outline)
	local fontSize 				= categoryFontSettings.size
	
	return self:BuildFontString(font, fontSize, fontOutline)
end

function QuestTracker:GetQuestFontString()
	local questFontSettings 	= self.svCurrent.fontSettings.quests
	local font 					= self:GetFontByName(questFontSettings.font)
	local fontOutline 			= self:GetOutlineByName(questFontSettings.outline)
	local fontSize 				= questFontSettings.size
	
	return self:BuildFontString(font, fontSize, fontOutline)
end
function QuestTracker:GetConditionFontString()
	local conditionFontSettings = self.svCurrent.fontSettings.conditions
	local font 					= self:GetFontByName(conditionFontSettings.font)
	local fontOutline 			= self:GetOutlineByName(conditionFontSettings.outline)
	local fontSize 				= conditionFontSettings.size
	
	return self:BuildFontString(font, fontSize, fontOutline)
end

--===========================================================--
--======= HOOKS =========--
--===========================================================--
-- Handles when quests are added/removed. List must be repopulated instead of manually adding/removing
-- a single quest because the game calls this function and the quest indices may change. Rather than
-- trying to loop through our entire tree, compare the data and fix things, we just repopulate
-- the tree by wiping it & recreating it.
-- Updates are handled differently

-- Calamath NOTE : ZO_QuestJournal_Keyboard.RefreshQuestMasterList has been deleted. (Update 28)
--                 Instead, use the "QuestListUpdated" callback. (see.  /ingame/zo_quest/questjournal_manager.lua  ZO_QuestJournal_Manager:BuildQuestListData())
--[[
local OrigRefreshQuestMasterList = ZO_QuestJournal_Keyboard.RefreshQuestMasterList
function ZO_QuestJournal_Keyboard:RefreshQuestMasterList()
	OrigRefreshQuestMasterList(self)
	
	QUESTTRACKER:RepopulateQuestTree()
end
]]

-- QUESTTRACKER must be passed in because it does not exist yet
local function HookUpdateCurrentChildrenHeightsToRoot(QUESTTRACKER)
	local rootNode = QUESTTRACKER.navigationTree.rootNode
	local metaTable = getmetatable(rootNode)
	local origUpdateCurrentChildrenHeightsToRoot = metaTable.UpdateCurrentChildrenHeightsToRoot
	
	function metaTable.UpdateCurrentChildrenHeightsToRoot(self)
		origUpdateCurrentChildrenHeightsToRoot(self)
		QUESTTRACKER:UpdateCurrentChildrenWidthsToRoot(self)
		
		if QUESTTRACKER.svCurrent.mainWindow.autoWindowSizeWidth then
			QUESTTRACKER:AutoSizeWinWidth()
		end
		
		if QUESTTRACKER.svCurrent.mainWindow.autoWindowSizeHeight then 
			QUESTTRACKER:AutoSizeWinHeight()
		end
	end
end

--===========================================================--
--======= LOCAL REGISTERED CALLBACK/EVENT FUNCTIONS =========--
--===========================================================--
-- Registered callback for QuestTrackerAssistStateChanged, to select the quest
-- which, in turn, scrolls the node into view.
local function OnAssistChanged(self, unassistedData, assistedData)
	if not assistedData then return end
	local questIndex = assistedData.arg1
	
	--[[ ALLOW_QUEST_ASSIST_CALLBACK is used here because the game fires this more than once on load, before finally deciding what quest should be originally selected, this blocks that so random auto-tooltips don't get displayed on load and so that nodes don't get opened by those random calls and left open if the user has node exclusitivity off.
	--]]
	if questIndex and ALLOW_QUEST_ASSIST_CALLBACK then
		self:SelectQuestIndexNode(questIndex, true)
		
		if self.svCurrent.tooltips.autoTooltip and not QUESTTRACKER.WINDOW_FRAGMENT:IsHidden() then
			self:ShowQuestTooltip(questIndex)
			
			local fadeTime = self.svCurrent.tooltips.fadeTime*1000
			EVENT_MANAGER:RegisterForUpdate("QuestTrackerClearAutoTooltip", fadeTime, function() 
				ClearTooltip(InformationTooltip) 
				EVENT_MANAGER:UnregisterForUpdate("QuestTrackerClearAutoTooltip")
			end)
		end
	end
end

-- This is cheesy, but the node won't scroll into view on player activation. The scroll 
-- doesn't have its extents updated yet & its still 0 so it can't scroll, must delay.
local function OnPlayerActivated()
	QUESTTRACKER.hasEventPlayerActivatedTriggered = true
	zo_callLater(function() QUESTTRACKER:RefreshSelectedQuest() end, 10)
	
	-- Allow auto-tooltips after the player has completely activated AND the game has finished firing all  
	-- callbacks for setting the current quest to prevent displaying an auto-tooltip on load, reloadUI, & zoning
	zo_callLater(function() ALLOW_QUEST_ASSIST_CALLBACK = true end, 100)
	
	--  Initialize the ingame questtracker state.  Needed to ensure ZOS QT is hidden on initial load of the addon or a new character.
	local newSetting = QUESTTRACKER.svCurrent.hideDefaultQuestTracker and "false" or "true"
	SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER, newSetting)
end

local function OnPlayerDeactivated()
	-- Set to false to block auto-tooltips until the player is completely Re-activated
	ALLOW_QUEST_ASSIST_CALLBACK = false
end

local function OnQuestAdded(eventCode, journalIndex, questName)
    local chatAlertType = QUESTTRACKER.svCurrent.chatAlertType
    
	-- V3.8.2.14 Calamath NOTE : 
	-- The original FOCUSED_QUEST_TRACKER:OnQuestAdd function was changed in Update 38 to allow the UI setting to select whether or not to switch the focused quest when a new quest is accepted. 
	-- Thus, add-ons no longer need to switch the focused quest. The following code has been removed.
--[[
    if QUESTTRACKER.svCurrent.questTrackForceAssist then
        FOCUSED_QUEST_TRACKER:ForceAssist(journalIndex)
    end
]]
    if chatAlertType == "Off" then return end
    
    local fQuestName = zo_strformat(SI_QUEST_JOURNAL_QUEST_NAME_FORMAT, questName)
    local darkOrange = "FFA500"
    local questAddedMsg = zo_strformat("|c<<1>><<2>>:|r <<3>>", darkOrange, "Quest Added: ", fQuestName)

    if chatAlertType == "Detailed" then
        local isValid, questData = LQI:GetCurrentQuestStepInfo(journalIndex)
        
        if isValid then
            questAddedMsg = zo_strformat("|c<<1>><<2>>:|r <<3>>", darkOrange, fQuestName, questData.stepText)
        end
    end
    d(questAddedMsg)	
end

-- called on event EVENT_LEVEL_UPDATE
local function OnLevelUpdate(eventCode, unitTag, level) 
	if unitTag ~= "player" then return end
	
	-- This will update all nodes, forcing their setup functions to fire. Specifically we want
	-- all of the QuestNodeSetup 's to fire so they will recall GetCon(nodeData.level) & RefreshTextColor()
	QUESTTRACKER.navigationTree:RefreshVisible()
end

-- Called on events EVENT_QUEST_ADVANCED & EVENT_QUEST_CONDITION_COUNTER_CHANGED & EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED
-- If you have problems with quests not updating properly...this is where to start looking
local function OnQuestUpdate(eventCode, journalIndex)
	QUESTTRACKER:UpdateQuest(journalIndex)
end

-- temporary test, split up for debug messages
local function OnQuestAdvanced(eventCode, journalIndex)
	OnQuestUpdate(eventCode, journalIndex)
end

-- temporary test, split up for debug messages
local function OnQuestCondtionChange(eventCode, journalIndex)
	if not QUESTTRACKER.hasEventPlayerActivatedTriggered then return end		-- V3.8.2.12 Calamath NOTE : This is a failsafe to avoid UI errors caused by esoui bugs where certain quest update events occur before EVENT_PLAYER_ACTIVATED.
	OnQuestUpdate(eventCode, journalIndex)
end


-- V3.8.2.14 Calamath NOTE:
-- UI_SETTING_AUTOMATIC_QUEST_TRACKING is added in Update38 to allow the user to choose whether to switch the focused quest when a new quest is accepted.
-- OnInterfaceSettingChanged function has been revised because this add-on have the same and the two need to work together.
--
-- if the user toggles the "Show quest tracker" setting or the "Automatic quest tracking" setting, update it in settings
local function OnInterfaceSettingChanged(eventCode, system, settingId) 
	if not system == SETTING_TYPE_UI then return end
	if settingId == UI_SETTING_SHOW_QUEST_TRACKER then
		local newValue = not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)
	
		if QUESTTRACKER_HIDEDEFAULTQUESTTRACKERWINDOW then
			QUESTTRACKER_HIDEDEFAULTQUESTTRACKERWINDOW:UpdateValue(false, newValue)
-- V3.8.2.9 Calamath NOTE:
-- Addressed an issue where if the player changed the default quest tracker display settings in the system menu before opening the settings panel for this add-on, 
-- the settings would not be reflected in the add-on's save data.
		else
			QUESTTRACKER.svCurrent.hideDefaultQuestTracker = newValue
		end
-- V3.8.2.3 Calamath NOTE : Use FOCUSED_QUEST_TRACKER instead to avoid nil reference errors. And the UpdateVisibility method has no arguments.
--       ZO_FocusedQuestTracker:UpdateVisibility (false, newValue)
-- V3.8.3.3 Calamath NOTE : The method name was adjusted as part of the refactoring of the vanilla quest tracker in Update51.
--		FOCUSED_QUEST_TRACKER:UpdateVisibility()
		FOCUSED_QUEST_TRACKER:Update()
	elseif settingId == UI_SETTING_AUTOMATIC_QUEST_TRACKING then
		local newValue = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_AUTOMATIC_QUEST_TRACKING)
		if QUESTTRACKER_AUTOMATICTRACKADDEDQUEST then
			QUESTTRACKER_AUTOMATICTRACKADDEDQUEST:UpdateValue(false, newValue)
		else
			QUESTTRACKER.svCurrent.questTrackForceAssist = newValue
		end
	end
end

-- hide QT window when in combat
local function OnCombatStateChange(eventCode, isInCombat)
    local svCurrent = QUESTTRACKER.svCurrent
    -- If its manually hidden or the combat hide feature is off do nothing
    if svCurrent.hideQuestWindow or not QUESTTRACKER.svCurrent.hideInCombat then return end
    
    if isInCombat then
        QUESTTRACKER.questTreeWin:SetHidden(true)
        return
    end
    QUESTTRACKER.questTreeWin:SetHidden(false)
end

--=====================================================--
--======= QuestTracker NEW/INITIALIZE FUNCTIONS =========--
--=====================================================--
function QuestTracker:New()
	-- First setup references:
	self.questTreeWin 			= QuestTrackerWin
	self.backdrop				= QuestTrackerWinBackdrop
	self.dragBar				= QuestTrackerWinDragBar
	self.lockBtn				= QuestTrackerWinLockBtn
	self.unlockBtn				= QuestTrackerWinUnlockBtn
	self.navigationContainer	= QuestTrackerWinNavigationContainer
	self.codeVersion			= VERSION_CODE
	self.hasEventPlayerActivatedTriggered = false

	-- Here just in case I need it for later I wont have to look it up again.
	--ZO_HIGHLIGHT_TEXT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_HIGHLIGHT))
	--ZO_NORMAL_TEXT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
	--ZO_DISABLED_TEXT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_DISABLED))
	--ZO_SELECTED_TEXT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
	local norm = ZO_NORMAL_TEXT
	self.FONT_COLOR_NORMAL_DEFAULT = {norm.r, norm.g, norm.b, norm.a}
	
	-- Then setup the UI & everything else
	local defaultSV = {
		mainWindow = {
			offsetX = 100,
			offsetY = 100,
			width 	= 300,
			height 	= 400,
			locked	= false,
			isItLocked = false,
			hideLockIcon = "Never",
			hideQuestWindow = false,
			--hideWithUI = false,
			showInGameScene = false,
			autoWindowSizeHeight = true,
			autoWindowSizeWidth = true,
			backdrop = {
				backdropName 		= "Colored",	-- defaults to none in code
				backdropAlpha 		= .5, --1,
				backdropColor 		= {0,0,0,.5},   --{.25, .25, .25, 1},
				dragBarColor        = {1,1,1,.5},
				hideMungeOverlay 	= false,
				backdropHideOnLock 	= false,
			},
		},
		fontSettings = {
			categories = {
				font	= "Bold",
				outline	= "Soft Thick Shadow",
				size	= 20,
				color	= self.FONT_COLOR_NORMAL_DEFAULT,
			},
			quests = {
				font	= "Bold",
				outline	= "Soft Thick Shadow",
				size	= 16,
				color	= self.FONT_COLOR_NORMAL_DEFAULT,
			},
			conditions = {
				font	= "Bold",
				outline	= "Soft Thick Shadow",
				size	= 14,
				color	= self.FONT_COLOR_NORMAL_DEFAULT,
			},
		},
		nodeExclusitivity = {
			currentSetting	= "None",
			allNodes 		= false,
			categoryNodes 	= false,
			questNodes		= false,
			isTreeExclusive	= false,
		},
		tooltips = {
			show				= true,
			anchorPoint			= LEFT,
			relativeTo			= RIGHT,
			autoTooltip			= false,
			fadeTime			= 5,
		},
		autoOpenNodes			= false,
		autoOpenCategoryOnLogin	= false,
		showQuestLevel			= true,
		showNumCategoryQuests	= true,
		overrideConColors		= false,
		chatAlertType			= "Detailed",
		questTrackForceAssist   = true,
		accountWide				= true,
		hideDefaultQuestTracker = true,
        hideFocusedQuestTracker = true,
		hideInCombat			= true,		-- Hide RQT window when in combat
		sortByLevel				= true,			-- Sort Quests by level
	}
	
	--********************************************************************************************--
	--                SavedVar stuff MUST be done before inializing the tree
	--********************************************************************************************--
	-- Will hold the saved vars, either: accountwdie or per character:
    self.svCurrent = {}
 
    self.svAccount = ZO_SavedVars:NewAccountWide("QuestTrackerSavedVars", 3.0, nil, defaultSV)
    self.svCharacter = ZO_SavedVars:New("QuestTrackerSavedVars", 3.0, nil, defaultSV)
    self:SwapSavedVars(self.svAccount.accountWide)
	--********************************************************************************************--

	-- Initialize HotKeys
	ZO_CreateStringId("SI_BINDING_NAME_QUESTTRACKER_TOGGLE_MAIN_WINDOW", "Toggle the Quest Tracker Window")
	
	-- Setup the tree
	local scrollChild 		= self.questTreeWin:GetNamedChild("NavigationContainerScrollChild")
    local navigationTree 	= ZO_Tree:New(scrollChild, 25, 0, 1000)
	
	self.navigationTree = navigationTree
	
	self:InitializeTree() -- initialize the tree, must be done before Initialize()
	
	self:Initialize()  -- initialize everything else
	
	return self
end

-- Initialize everything else
function QuestTracker:Initialize()
	local svMainWindow = self.svCurrent.mainWindow
	
	self:InitializeWindow()
	
	HookUpdateCurrentChildrenHeightsToRoot(self) -- do before population so it auto-fires resize
	
	-- V3.8.3.4 Calamath NOTE :
	-- In Update 51, the behavior of the focused quest cycling was changed so that it no longer cycles unless the vanilla quest tracker is displayed.
	-- Here, we'll register hooks and a callback to replicate the pre-update cycling behavior when the vanilla quest tracker is hidden.
	SecurePostHook(ZO_HUDTracker_Manager, "BeginAssistInteract", function()
		self.assistedAspirationOnBeginInteract = HUD_TRACKER_MANAGER:GetAssistedAspiration()
	end)
	HUD_TRACKER_MANAGER:RegisterCallback("AssistedAspirationChanged", function()
		self.assistedAspirationOnBeginInteract = nil	-- Prevent switching focused quest
	end)
	SecurePostHook(ZO_HUDTracker_Manager, "EndAssistInteract", function()
		local isVanillaQuestTrackerVisible = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)
		if not isVanillaQuestTrackerVisible and HUD_TRACKER_MANAGER:GetAssistedAspiration() == self.assistedAspirationOnBeginInteract then
			-- validity check: whether the interaction was triggered by ASSIST_NEXT_TRACKED_QUEST.
			local keyCode = GetHighestPriorityActionBindingInfoFromName("ASSIST_NEXT_TRACKED_QUEST", false)
			local isValid = true
			for activeLayerIndex = 1, GetNumActiveActionLayers() do
				local actionName = GetActionNameFromKey(GetActionLayerInfo(GetActiveActionLayerIndex(activeLayerIndex)), keyCode)
				isValid = isValid and (actionName == "" or actionName == "ASSIST_NEXT_TRACKED_QUEST")
			end
			if isValid then
				FOCUSED_QUEST_TRACKER:AssistNext()
			end
		end
	end)

	self:RepopulateQuestTree()	-- populates the tree with categories/quests/conditions
	
	QuestTracker_CreateSettingsMenu(self)
	
	-- Sets the selected quest in our tree, whenever it is changed somewhere else
	FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", function(unassistedData, assistedData) OnAssistChanged(self, unassistedData, assistedData) end)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INTERFACE_SETTING_CHANGED, 	  OnInterfaceSettingChanged) 
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestCondtionChange)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED, OnQuestCondtionChange)	-- Calamath NOTE : Support for the new event added in Update 30
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_ADDED,			OnQuestAdded)	-- only for chat window alert
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, 		OnPlayerActivated) 
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEACTIVATED, 	OnPlayerDeactivated) 
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_ADVANCED, 		OnQuestAdvanced)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_LEVEL_UPDATE, 			OnLevelUpdate)	-- To update con colors when leveling
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, 	OnCombatStateChange)	-- To hide QT when in combat

	-- V3.8.2.3 Calamath NOTE : 
	-- the original FOCUSED_QUEST_TRACKER:OnQuestAdd function is responsible for always switching the focused quest to it when a new quest is accepted.
	-- This is a feature added to the Vanilla UI in a recent update.
	-- This add-on has an option switch that controls whether or not to track the focus quest, so we need to disable the original OnQuestAdd function here.
	-- V3.8.2.14 Calamath NOTE : 
	-- The original FOCUSED_QUEST_TRACKER:OnQuestAdd function was changed in Update 38 to allow the UI setting to select whether or not to switch the focused quest when a new quest is accepted. 
	-- Therefore, add-ons no longer need to interfere with the OnQuestAdd function and the change in V3.8.2.3 has been removed.
--[[
	if FOCUSED_QUEST_TRACKER.OnQuestAdded then
		-- Returning true in the Hook function means blocking the execution of the original FOCUSED_QUEST_TRACKER:OnQuestAdd function.
		ZO_PreHook(FOCUSED_QUEST_TRACKER, "OnQuestAdded", function(self, questIndex) return true end)
	end
]]
	-- Auto open options
	if self.svCurrent.autoOpenNodes then
        self:OpenAllQuestNodes()
    end
	
	if self.svCurrent.autoOpenCategoryOnLogin then
	    self:OpenSelectedCategoryQuestNodes()
	end
	
	-- Since we can't add/remove quests and must instead repopulate the entire tree when these happen
	-- because the game calls RefreshQuestMasterList at which time
	-- quest indices may change and it also calls RefreshQuestMasterList on init during zone changes.
	-- Were not going to use these, but instead just hook the RefreshQuestMasterList instead. 
	-- If we registered these & hooked RefreshQuestMasterList every time one of these events fired
	-- our code would get run twice, once for the event firing & once for the RefreshQuestMasterList firing.
	--EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_ADDED,			OnQuestAdded)
	--EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_REMOVED, 		OnQuestRemoved)
	--EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_LIST_UPDATED, function() self:RepopulateQuestTree() end)

	-- Calamath NOTE : Since Update 28, "QuestListUpdated" callback will be fired every time the ZO_QuestJournal_Manager:BuildQuestListData() finishes.
	QUEST_JOURNAL_MANAGER:RegisterCallback("QuestListUpdated", function() self:RepopulateQuestTree() end)
end

function QuestTracker:InitializeWindow()
	local svMainWindow 	= self.svCurrent.mainWindow
	local offsetX 		= svMainWindow.offsetX
	local offsetY 		= svMainWindow.offsetY
	local width		 	= svMainWindow.width
	local height 		= svMainWindow.height
	local isItLocked		= svMainWindow.isItLocked
	
	self.questTreeWin:ClearAnchors()
	self.questTreeWin:SetAnchor(TOPLEFT, nil, TOPLEFT, offsetX, offsetY)
	self.questTreeWin:SetDimensions(width, height)
	
	self:UpdateBackdrop(svMainWindow.backdrop.backdropName)
	self:SetLockState(svMainWindow.isItLocked)
	
	local WINDOW_FRAGMENT 	= ZO_HUDFadeSceneFragment:New(self.questTreeWin)
	self.WINDOW_FRAGMENT 	= WINDOW_FRAGMENT

    --Automatically show QuesTracker when game says to	
    HUD_SCENE:AddFragment(WINDOW_FRAGMENT)							
    HUD_UI_SCENE:AddFragment(WINDOW_FRAGMENT)

	--Use this with force show setting in options above "auto" lines override this (use either those or this)
	-- wtf? lol thats obviously not one of my comments !!!
	-- Add/Remove fragment from the GAME_MENU_SCENE
    QuestTracker:SetupFragmentForGameScene(svMainWindow.showInGameScene)
	
	self:UpdateWindowVisibility(self.svCurrent.mainWindow.hideQuestWindow)
end

--===========================================================--
--==================== UTILITY CODE =========================--
--===========================================================--

function QuestTracker:SwapSavedVars(useAccountWide)
    if useAccountWide then
        self.svCurrent = self.svAccount
    else
        self.svCurrent = self.svCharacter
    end
end	

function QuestTracker_ToggleWindow()
	local questWindow 			= QUESTTRACKER.questTreeWin
	local svMainWindow 			= QUESTTRACKER.svCurrent.mainWindow
	local hideQuestWindow 		= not svMainWindow.hideQuestWindow
	svMainWindow.hideQuestWindow = hideQuestWindow
	
	QUESTTRACKER.WINDOW_FRAGMENT:SetHiddenForReason("QuestTracker_UserSetting_Hidden", hideQuestWindow)
end

function QuestTracker:UpdateWindowVisibility(shouldHide)
	local hideQuestWindow = shouldHide or self.svCurrent.mainWindow.hideQuestWindow
	
	self.WINDOW_FRAGMENT:SetHiddenForReason("QuestTracker_UserSetting_Hidden", hideQuestWindow)
end

-- your shouldHide doesn't match with what its doing. It says if shouldHide then add it to the scene
-- which makes it visible. Thats not hiding it. Changing it.
function QuestTracker:SetupFragmentForGameScene(showInGameScene)    -- for force show setting
    local showInGameScene	= showInGameScene or self.svCurrent.mainWindow.showInGameScene
    local WINDOW_FRAGMENT	= self.WINDOW_FRAGMENT
    
    if showInGameScene then
        GAME_MENU_SCENE:AddFragment(WINDOW_FRAGMENT)
    else
        GAME_MENU_SCENE:RemoveFragment(WINDOW_FRAGMENT)
    end
end

-- Auto Size functions
function QuestTracker:AutoSizeWinHeight()
	if not self.svCurrent.mainWindow.autoWindowSizeHeight then return end
	
	local childrenCurrentHeight = self.navigationTree.rootNode.childrenCurrentHeight
    local win         			= self.questTreeWin
    
    local width, height = win:GetDimensions()
    local dragBarHeight = self.dragBar:GetHeight()
    
    -- +5 is padding for the -5 offsetY anchor on the navigationContainer
    -- +2 to prevent the scrollbar from flashing as the extents change
    height = childrenCurrentHeight+dragBarHeight+7
	
    win:SetDimensions(width, height)
end

function QuestTracker:AutoSizeWinWidth()
	if not self.svCurrent.mainWindow.autoWindowSizeWidth then return end
	
	local maxNodeWidth = self.navigationTree.width
	
	local win = self.questTreeWin
	local width, height = win:GetDimensions()
	
	-- Padding for scrollbar width 16 + navigationContainer both offsetX anchors left & right 5 each (in xml)
	win:SetDimensions(maxNodeWidth+26, height)
end

-- Calculates & returns the container width required for treeNode and all of its children.
function QuestTracker:CalculateNodeContainerWidths(treeNode, totalIndent)
	local children = treeNode.children
	local treeNodeIndent = totalIndent or 0
	local treeNodeWidth = (treeNode.totalControlWidth or 0) + treeNodeIndent
	local containerWidth = 0
	
    if(children and treeNode:IsOpen()) then
		local childIndent = treeNodeIndent+treeNode.childIndent
		
        for i = 1, #children do
            local childNode = children[i]
			local childContainerWidth = self:CalculateNodeContainerWidths(childNode, childIndent)
			
			containerWidth = zo_max(containerWidth, childNode.totalControlWidth+childIndent, childContainerWidth)
        end
	end
	containerWidth = zo_max(treeNodeWidth, containerWidth)
	
	treeNode.containerWidth = containerWidth
	treeNode.NodeIsIndentedBy = treeNodeIndent
	
	return containerWidth
end


function QuestTracker:UpdateCurrentChildrenWidthsToRoot()
	local tree 					= self.navigationTree
	local rootNode 				= tree.rootNode
	local rootContainerWidth 	= self:CalculateNodeContainerWidths(rootNode)
	
	tree.width = rootContainerWidth
	tree.control:SetWidth(rootContainerWidth)
	
	local function UpdateChildWidths(treeNode)
		local control 			= treeNode.control
		local childContainer 	= treeNode.childContainer
		local children 			= treeNode.children
		local containerWidth 	= treeNode.containerWidth
		
		if control then
			control:SetWidth(containerWidth)
		end
		if childContainer then
			childContainer:SetWidth(containerWidth)
		end
		
		if(children) then
			for i = 1, #children do
				local child = children[i]
				UpdateChildWidths(child)
			end
		end
	end
	UpdateChildWidths(rootNode)
end

function QuestTracker:ScrollQuestNodeIntoView(questIndex, questNode) 
	local questNode = questNode or self.navigationTree.questIndexToTreeNode[questIndex]
	
	if questNode then
		ZO_Scroll_ScrollControlIntoCentralView(self.navigationContainer, questNode.control)
	end
end

-- Get the tree node for the currently selected quest. If it exists, set that node selected
function QuestTracker:SelectQuestIndexNode(questIndex, scrollIntoView) 
	local selectedQuestNode = self.navigationTree.questIndexToTreeNode[questIndex]
	
	if selectedQuestNode then
        selectedQuestNode:OnSelected()
		
		if scrollIntoView then
			self:ScrollQuestNodeIntoView(questIndex, selectedQuestNode) 
		end
	end
end

function QuestTracker:RefreshSelectedQuest()
	local selectedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	
	self:SelectQuestIndexNode(selectedQuestIndex, true)
end

function QuestTracker:ShowQuestTooltip(questIndex)
	if QUESTTRACKER.WINDOW_FRAGMENT:IsHidden() then return end
	
	local svTooltips	= self.svCurrent.tooltips
	local anchorPoint 	= svTooltips.anchorPoint
	local relativeTo 	= svTooltips.relativeTo
	
	-- In case auto-tooltips are on & a tooltip was just set...and the user
	-- mouses over a quest node, which opens a new tooltip. We don't want it to fade until the user
	-- exits the node with the mouse, so cancel auto registered ClearTooltip
	EVENT_MANAGER:UnregisterForUpdate("QuestTrackerClearAutoTooltip")
	
	InitializeTooltip(InformationTooltip, self.questTreeWin, anchorPoint, 0, 0, relativeTo)
	
	LQI:CreateQuestTooltip(questIndex, InformationTooltip)
end

function QuestTracker:SetLockState(lock)
	local lockBtn 				= self.lockBtn
	local unlockBtn 			= self.unlockBtn
	local mainWin 				= self.questTreeWin
	local svMainWindow			= self.svCurrent.mainWindow
	local svMainWindowBackdrop 	= svMainWindow.backdrop
	
	svMainWindow.isItLocked = lock
	
	local isWindowLocked = lock
	local isWindowUnlocked = not lock
	
    if svMainWindow.hideLockIcon == "Never" then 
		lockBtn:SetHidden(isWindowUnlocked)
		lockBtn:SetEnabled(isWindowLocked)
		unlockBtn:SetHidden(isWindowLocked)
		unlockBtn:SetEnabled(isWindowUnlocked)
	elseif svMainWindow.hideLockIcon == "Always" then
		unlockBtn:SetHidden(true)
		lockBtn:SetHidden(true)		
	elseif svMainWindow.hideLockIcon == "Locked" then
		lockBtn:SetHidden(true)
		unlockBtn:SetHidden(isWindowLocked)
		unlockBtn:SetEnabled(isWindowUnlocked)		
	end
	
	mainWin:SetMovable(isWindowUnlocked)
	mainWin:SetMouseEnabled(isWindowUnlocked)
	
	if not svMainWindowBackdrop.backdropHideOnLock then return end
	
	local backdropControl 	= self.backdrop
	local dragBar			= self.dragBar
	local isBackdropHidden 	= backdropControl:IsHidden()
	
	if isWindowLocked and not isBackdropHidden then
		backdropControl:SetHidden(true)
		dragBar:SetHidden(true)
	end
		
	if isWindowUnlocked and isBackdropHidden then
		if svMainWindowBackdrop.backdropName ~= "None" then
			backdropControl:SetHidden(false)
			dragBar:SetHidden(false)
		end
	end
end

-- DONT try to compare condition nodes. I did not write an equality function for them
-- we don't need it. Were not updating condition nodes. When needed we wipe them out & re-add them.
function QuestTracker:AreTreeNodesEqual(treeNode1, treeNode2)
	if treeNode1.equalityFunction == treeNode2.equalityFunction then
		if treeNode1.equalityFunction(treeNode1.data, treeNode2.data) then
			return true
		end
	end
	return false
end

--===========================================================--
--=========== ADD/REMOVE NODE UTILITY CODE ==================--
--===========================================================--
function QuestTracker:UpdateChildHeightsToRoot(treeNode)
    treeNode:UpdateChildrenHeightsToRoot()
	treeNode:UpdateCurrentChildrenHeightsToRoot()
	
	-- widths are now updated in the hook on UpdateCurrentChildrenHeightsToRoot()
end

-- When removing a node, this is used to reanchor the previous node to the next node
function QuestTracker:AnchorPreviousNodeToNextNode(nodeToRemove)
	local previousNode 	= self:GetPreviousNode(nodeToRemove)
	local parentNode	= nodeToRemove.parentNode
	local nextNode		= nodeToRemove.nextNode
	
	if nextNode then
		local childControl = nextNode:GetControl()
		-- This is not needed, nextNode is already a sibling, were only ever reanchoring siblings
		childControl:SetParent(parentNode.childContainer)
		
		if(previousNode) then
			previousNode:AttachNext(nextNode)
		else
			childControl:ClearAnchors()
			childControl:SetAnchor(TOPLEFT, parentNode.childContainer, TOPLEFT, parentNode.childIndent, 0)
		end
	end

	self:UpdateChildHeightsToRoot(parentNode)
end

-- Used to get the previous node, to reanchor nodes, when removing a node
function QuestTracker:GetPreviousNode(treeNode)
	local parentNode 	= treeNode.parentNode
	local siblingsTable = parentNode.children
	local next			= next
	
	if not siblingsTable or next(siblingsTable) == nil then return end
	
	for k, siblingNode in pairs(siblingsTable) do
		if self:AreTreeNodesEqual(treeNode, siblingNode)then
		
			-- If treeNode is the first indexed child, this will be k-1 = 0 & it will return nil, thats ok
			-- It is expected to return nil if treeNode is the first child
			return siblingsTable[k-1]
		end
	end
end

-- Used to get the table index for a treeNode, when removing nodes, so that after we 
-- release all of the node objects we can remove the node reference from the node table.
function QuestTracker:GetNodeTableIndex(treeNode)
	local parentNode 	= treeNode.parentNode
	local siblingsTable = parentNode.children

	for tableIndex, siblingNode in pairs(siblingsTable) do
		if self:AreTreeNodesEqual(treeNode, siblingNode)then
			return tableIndex
		end
	end
end

-- When creating a new Category node this is used to get the categories default table data
function QuestTracker:GetDefaultCategoryNodeData(categoryName, allCategories)
	for k, categoryData in pairs(allCategories) do
		if categoryData.name == categoryName then
			return categoryData
		end
	end
end

-- When we add quest nodes, this is used to get the correct parent (category) node
-- This happens before the quest node is created, so we can't use questNode.parentNode...we
-- need to know what categoryNode to create the quest node under
function QuestTracker:GetCategoryNodeByName(categoryName)
	local rootChildren = self.navigationTree.rootNode.children
	
	for k, categoryNode in ipairs(rootChildren) do
		if categoryNode.data.name == categoryName then
			return categoryNode
		end
	end
end

-- Add step & condition info to the questData table
local function AddStepConditionInfo(questData)
	local questInfo = LQI:GetCurrentQuestInfo(questData.questIndex)
	
	local trackerOverrideText 		= questInfo.trackerOverrideText
	questData.stepIndex 			= questInfo.stepIndex -- Only for /zgoo debugging, not used
	questData.stepText 				= questInfo.stepText  -- Only for /zgoo debugging, not used
	questData.trackerOverrideText 	= trackerOverrideText
	
	-- This really isn't a condition, but we want to display it like one if it exists instead of the conditions.
	-- BE AWARE, by doing this it means that other condition info you see in the condition tables like
	-- current, isComplete, isCreditShared, exc... will not always be available in the table...here we will
	-- only store the tracker override text because thats what is suppposed to be displayed & it does not belong
	-- to any single condition, so we can't just copy another conditions info...there may not even be any 
	-- other conditions.
	if(trackerOverrideText and trackerOverrideText ~= "") then
		local fOverrideStepText = zo_strformat(SI_QUEST_HINT_STEP_FORMAT, trackerOverrideText)
		
		questData.conditions = {
			[1] = {conditionText = fOverrideStepText},
		}
	else
		questData.conditions = questInfo.conditions 
	end
	
	return questData
end

--===========================================================--
--================ SORT/REANCHOR CODE =======================--
--===========================================================--
-- Called from SortChildrenByType to reanchor the children after they have been sorted
function QuestTracker:ReanchorChildren(parentNode)
	local siblingsTable = parentNode.children
	
	if not siblingsTable then return end

	local previousNode = nil
	
	for _, treeNode in ipairs(siblingsTable) do
		treeNode.nextNode = nil
		
		if previousNode then
			previousNode:AttachNext(treeNode)
		else
			local treeNodeControl = treeNode:GetControl()
			treeNodeControl:ClearAnchors()
			treeNodeControl:SetAnchor(TOPLEFT, parentNode.childContainer, TOPLEFT, parentNode.childIndent, 0)
		end
		
		previousNode = treeNode
	end
	
	self:UpdateChildHeightsToRoot(parentNode)
end

--==================================================================================================--
-- ZO_TreeNode will not let you insert a child into a specific position & ZO_TreeNode is local. 
-- So to keep nodes in order, we let the game add it to the end of the list, resort 
-- the node table, and then re-anchor the nodes in the table.
--==================================================================================================--
-- NEVER try to sort the condition nodes !!!
-- They are ordered in a special way, for step/condition order & visibility
--==================================================================================================--
--**** Sorts by category type and THEN by name, so all items may not "appear" to show up in alphabetical order ****--
--**** This was intentional ****--
function QuestTracker:SortQuestNodes(sortByLevel)
	local sortByLevel = sortByLevel or self.svCurrent.sortByLevel
    local categoryTable = self.navigationTree.rootNode.children
    
    for k,categoryNode in pairs(categoryTable) do
        self:SortChildrenByType(categoryNode, SORT_TYPE_QUESTS)
    end
end

function QuestTracker:SortChildrenByType(parentNode, sortType)
	local siblingsTable = parentNode.children
	if not siblingsTable then return end

	if sortType == SORT_TYPE_QUESTS then	    
        local sortByLevel = self.svCurrent.sortByLevel
		local function SortQuestTableEntries(questTableEntry1, questTableEntry2)
			local quest1NodeData = questTableEntry1.data
			local quest2NodeData = questTableEntry2.data
			
			if quest1NodeData.categoryType == quest2NodeData.categoryType then
				if quest1NodeData.categoryName == quest2NodeData.categoryName then
					if sortByLevel then
                        return quest1NodeData.level < quest2NodeData.level
                    end
                    return quest1NodeData.name < quest2NodeData.name
				end
				return quest1NodeData.categoryName < quest2NodeData.categoryName
			end
			return quest1NodeData.categoryType < quest2NodeData.categoryType
		end
		
		table.sort(siblingsTable, SortQuestTableEntries)
		
	elseif sortType == SORT_TYPE_QUEST_CATEGORIES then
		local function SortCategoryTableEntries(categoryTableEntry1, categoryTableEntry2)
			local category1NodeData = categoryTableEntry1.data
			local category2NodeData = categoryTableEntry2.data
			
			if category1NodeData.type == category2NodeData.type then
				return category1NodeData.name < category2NodeData.name
			else
				return category1NodeData.type < category2NodeData.type
			end
		end
		
		table.sort(siblingsTable, SortCategoryTableEntries)
	end
	self:ReanchorChildren(parentNode)
end

--=============================================================--
--==================== ADD NODE CODE ==========================--
--=============================================================--
function QuestTracker:AddCategoryNode(categoryData, parentNode)
    local headerNode = self.navigationTree:AddNode("QuestTrackerCategoryNode", categoryData, parentNode, SOUNDS.QUEST_BLADE_SELECTED)
    
    return headerNode
end

function QuestTracker:AddQuestEntryNode(questData, parentNode)
    local questNode = self.navigationTree:AddNode("QuestTrackerQuestNode", questData, parentNode, SOUNDS.QUEST_SELECTED)
    self.navigationTree.questIndexToTreeNode[questData.questIndex] = questNode    
	
    if QUESTTRACKER and QUESTTRACKER.svCurrent.autoOpenNodes then
        questNode:SetOpenPercentage(1)
        questNode.open = true
    end
    
    return questNode
end

function QuestTracker:AddQuestConditionNode(conditionData, parentNode)
    local conditionNode = self.navigationTree:AddNode("QuestTrackerConditionNode", conditionData, parentNode, nil)
    
    return conditionNode
end


--=============================================================--
--================== UPDATE QUEST CODE ========================--
--=============================================================--
-- Used to update quest condition nodes...well actualy wipe them out & recreate them
-- on quest advance or quest condition counter change. We wipe them out rather than update them because
-- its much easier/faster than looping through each node to edit/add new conditions & looping through again
-- to wipe out any old left over condition nodes that are no longer valid
function QuestTracker:UpdateQuest(journalIndex)
	local tree = self.navigationTree
	local questNode = tree.questIndexToTreeNode[journalIndex]

	-- If it doesn't exist....something is wrong somewhere else
	assert(questNode, string.format("UpdateQuest failed. Quest does not exist in the quest tree. (Index=%s, Name=%s, isValid=%s)", tostring(journalIndex), GetJournalQuestName(journalIndex), tostring(IsValidQuestIndex(journalIndex))))
	
	-- Not really the most efficient method here, but easy
	local allQuests, allCategories, seenCategories = QUEST_JOURNAL_MANAGER:GetQuestListData()
	local newQuestData
	
	for k,questData in pairs(allQuests) do
		if questData.questIndex == journalIndex then
			newQuestData = questData
			break
		end
	end
	-- If newQuestData doesn't exist....something is wrong, the quest must have been removed somehow/somewhere
	-- and it wasn't supposed to be or else an update event would not have fired, but don't do this:
	-- if not newQuestData then return end....we want an error to let us know whats wrong
	assert(newQuestData, "UpdateQuest failed. Quest does not exist in the QUEST_JOURNAL_MANAGER")
	
	self:ReleaseAllQuestConditionNodes(questNode)
	
	-- Add step & condition info to the newQuestData table
	AddStepConditionInfo(newQuestData)
	
	questNode.data = newQuestData
	
	-- Add all of the new condition nodes....NEVER sort the condition nodes !!!
	-- They are already ordered in a special way, for step/condition order & visibility
	local conditions = newQuestData.conditions
	for conditionKey, conditionData in ipairs(conditions) do
		local conditionNode = self:AddQuestConditionNode(conditionData, questNode)
	end
	self:UpdateChildHeightsToRoot(questNode)
end

--=============================================================--
--=============== ADD/REMOVE CATEGORY CODE ====================--
--=============================================================--
-- When a quest is added, if the category does not already exist, used to add the new quest category
function QuestTracker:AddQuestCategory(categoryNodeData)
	local rootNode		= self.navigationTree.rootNode
	local categoryNode	= self:AddCategoryNode(categoryNodeData, rootNode)
	
	self:SortChildrenByType(rootNode, SORT_TYPE_QUEST_CATEGORIES)
	
	return categoryNode
end

--==============================================================--
--============ REPOPULATE/ADDTABLE NODES CODE ============--
--==============================================================--
function QuestTracker:RepopulateQuestTree()
	-- these tables are ALREADY sorted, so use ipairs !
	local allQuests, allCategories, seenCategories = QUEST_JOURNAL_MANAGER:GetQuestListData()
	local quests = {}
	
	-- Combine the quest/category data into one table
	for categoryKey, categoryData in ipairs(allCategories) do
		local categoryName = categoryData.name
		
		quests[categoryKey] = {
			name = categoryName,
			type = categoryData.type,
			-- Note this quests table is ONLY valid here & in the below call to AddTableNodes, when repopulating the 
			-- tree from scratch. When we add/remove/update nodes we do NOT update this quests table...theres no need to.
			-- This is only to reorganize the data returned by GetQuestListData to make the repopulation/AddTableNodes() easier.
			quests = {}
		}
		for questKey, questData in ipairs(allQuests) do
			if questData.categoryName == categoryName then
				AddStepConditionInfo(questData)
				
				table.insert(quests[categoryKey].quests, questData)
			end
		end
		if self.svCurrent.sortByLevel then
            local function SortQuestsByLevel(questTableEntry1, questTableEntry2)
				return questTableEntry1.level < questTableEntry2.level
            end
            table.sort(quests[categoryKey].quests, SortQuestsByLevel)
        end
	end
	
	self:AddTableNodes(quests, nil)
	
	-- If there are quests when the table nodes are added it automatically calls
	-- the required functions to resize the window. If the quests table is empty, no quests
	-- no nodes are added so we must call the update ourselves.
	if next(quests) == nil then
		self:UpdateChildHeightsToRoot(self.navigationTree.rootNode)
	end
	
	-- Must refresh selected quest, that way when quests are added or removed, 
	-- we keep the correct quest selected because the QuestTrackerAssistStateChanged
	-- will have already fired and it wont get updated by that !
	self:RefreshSelectedQuest()
	-- AFTER that, update the tree exclusitivity. Must be after so a quest is selected to set the 
	-- exclusive path if the tree is set as exclusive.
	self:UpdateTreeExclusitivity()
	self.navigationTree:RefreshVisible()    -- Extra refresh to prevent text from being chopped off (workaround for a ZOS issue)
end

function QuestTracker:AddTableNodes(allQuests, parentNode)
	local tree = self.navigationTree
	-- Clear the tree nodes & questIndexToTreeNode table
    tree:Reset()
	tree.questIndexToTreeNode = {}
	
	-- They are sorted use ipairs !!
	for categoryKey, categoryData in ipairs(allQuests) do
		local categoryNode = self:AddCategoryNode(categoryData, parentNode)
		local quests = categoryData.quests
		
		for questKey, questData in ipairs(quests) do
			local questNode = self:AddQuestEntryNode(questData, categoryNode)
			tree.questIndexToTreeNode[questData.questIndex] = questNode
			
			local conditions = questData.conditions
			for conditionKey, conditionData in ipairs(conditions) do
				local conditionNode = self:AddQuestConditionNode(conditionData, questNode)
			end
			questData.conditions = nil -- Wipe this out so you don't accidently "think" you can use it later, we don't update this data
		end
		categoryData.quests = nil -- Wipe this out so you don't accidently "think" you can use it later, we don't update this data
	end
	
	-- If the user has exclusitivity set to "All" so tree.exclusive == true this will cause problems if you do not
	-- specify which node to select...even though it really wont select the node because its not a leaf,
	-- it blocks the SelectAnything() func
	local selectedQuestIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
	local selectedQuestNode = self.navigationTree.questIndexToTreeNode[selectedQuestIndex]
    tree:Commit(selectedQuestNode)
	
	-- On category nodes, the number of quests is only set when the category node is created (or visible/control is refreshed)
	-- But children (quests) get added after that. So after were done adding all the quests, refresh the entire visible tree
	-- to update the number of quests for every category control
	tree:RefreshVisible()
end

--===========================================================--
--============ BACKDROP SETTINGS MENU FUNCTIONS  ============--
--===========================================================--
function QuestTracker:UpdateBackdropColor()
	local backdropControl 	= self.backdrop
	local bgColor 			= self.svCurrent.mainWindow.backdrop.backdropColor
	local dragBar 			= self.dragBar
	local r,g,b,alpha		= unpack(bgColor)
	
	backdropControl:SetCenterColor(r,g,b,alpha)
	backdropControl:SetEdgeColor(r,g,b,alpha)
	dragBar:SetAlpha(alpha)
end
function QuestTracker:UpdateDragBarColor()
    local bgColor             = self.svCurrent.mainWindow.backdrop.dragBarColor
    local dragBar             = self.dragBar
    local r,g,b,alpha        = unpack(bgColor)
    
    dragBar:SetCenterColor(r,g,b,alpha)
    --dragBar:SetEdgeColor(r,g,b,alpha)
end

function QuestTracker:UpdateBackdrop(backdropName)
	local backdropControl 		= self.backdrop
	local dragBar				= self.dragBar
	local mungeOverlay			= backdropControl:GetNamedChild("MungeOverlay")
	
	local svMainWindow 			= self.svCurrent.mainWindow
	local svMainWindowBackdrop	= svMainWindow.backdrop
	local bgColor 				= svMainWindowBackdrop.backdropColor
	local backdropName 			= backdropName or svMainWindowBackdrop.backdropName
	
	if svMainWindowBackdrop.hideMungeOverlay then 
		mungeOverlay:SetHidden(true)
	else
		mungeOverlay:SetHidden(false)
	end
	
	if backdropName == "None" then
		backdropControl:SetHidden(true)
		dragBar:SetHidden(true)
		
	else
		if backdropName == "Fancy" then
			backdropControl:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds", 16, WRAP)
			backdropControl:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 0, 0)
			backdropControl:SetEdgeColor(1,1,1,1)
		
		elseif backdropName == "Colored" then
			backdropControl:SetCenterTexture(nil, 16, WRAP)
			backdropControl:SetEdgeTexture(nil, 128, 16, 0, 0) 
			local r,g,b,alpha = unpack(bgColor)
			backdropControl:SetCenterColor(r,g,b,alpha)
			backdropControl:SetEdgeColor(r,g,b,alpha)
			local dragBar = self.dragBar
			self:UpdateDragBarColor()
			dragBar:SetAlpha(alpha)
		end
		local shouldHide = svMainWindowBackdrop.backdropHideOnLock and svMainWindow.isItLocked 
        backdropControl:SetHidden(shouldHide)
        dragBar:SetHidden(shouldHide)
	end
end

--==========================================================--
--==================  EXCLUSITIVITY CODE  ==================--
--==========================================================--
function QuestTracker:OpenAllQuestNodes()
    local tree            = self.navigationTree
    local selectedNode     = tree.selectedNode
    
    -- The game is still loading, the user has no quests...or else theres always something selected?
    if not selectedNode then return end
    
    local categoryNodesTable     = tree.rootNode.children
    
    for k,categoryNode in pairs(categoryNodesTable) do
        local questNodeTable = categoryNode.children
        
        for k,questNode in pairs(questNodeTable) do
            tree:SetNodeOpen(questNode, true, USER_REQUESTED_OPEN)
        end
    end
end

function QuestTracker:OpenSelectedCategoryQuestNodes()
    local tree            = self.navigationTree
    local selectedNode     = tree.selectedNode
    
    -- The game is still loading, the user has no quests...or else theres always something selected?
    if not selectedNode then return end
    
	local selectedCategoryNode = selectedNode.parentNode
	local questNodeTable = selectedCategoryNode.children
        
    for k,questNode in pairs(questNodeTable) do
        tree:SetNodeOpen(questNode, true, USER_REQUESTED_OPEN)
    end
end

function QuestTracker:CloseAllQuestNodes()
	local tree			= self.navigationTree
	local selectedNode 	= tree.selectedNode
	
	-- The game is still loading, the user has no quests...or else theres always something selected?
	if not selectedNode then return end
	
	local categoryNodesTable 	= tree.rootNode.children
	
	for k,categoryNode in pairs(categoryNodesTable) do
		local questNodeTable = categoryNode.children
		
		for k,questNode in pairs(questNodeTable) do
			if questNode.open and not self:AreTreeNodesEqual(questNode, selectedNode) then
				tree:SetNodeOpen(questNode, false, USER_REQUESTED_OPEN)
			end
		end
	end
end

function QuestTracker:CloseAllCategoryNodes()
	local tree			= self.navigationTree
	local selectedNode 	= tree.selectedNode
	
	-- The game is still loading, the user has no quests...or else theres always something selected?
	if not selectedNode then return end 
	
	local categoryNodeTable = tree.rootNode.children
	local selectedCategoryNode = selectedNode.parentNode
	
	for k,categoryNode in pairs(categoryNodeTable) do
		if categoryNode.open and not self:AreTreeNodesEqual(categoryNode, selectedCategoryNode) then
			tree:SetNodeOpen(categoryNode, false, USER_REQUESTED_OPEN)
		end
	end
end

function QuestTracker:OpenAllCategoryNodes()
	local tree			= self.navigationTree
	local selectedNode 	= tree.selectedNode
	
	-- The game is still loading, the user has no quests...or else theres always something selected?
	if not selectedNode then return end 
	
	local categoryNodeTable = tree.rootNode.children
	local selectedCategoryNode = selectedNode.parentNode
	
	for k,categoryNode in pairs(categoryNodeTable) do
		if categoryNode.closed and not self:AreTreeNodesEqual(categoryNode, selectedCategoryNode) then
			tree:SetNodeOpen(categoryNode, true, USER_REQUESTED_OPEN)
		end
	end
end

--[[ Note we do not always need to "set" the saved vars for changing node exclusitivity, this is why it is split into 
     two functions For example, on load, we only need to update the newly created trees setting, so we pass in nil. But in 
     the settings menu we call SetTreeExclusitivity, which saves the new sv value & calls this function to update the tree 
     setting. In that route, since we already have the nodeExclusitivity table theres no reason to look it up again here, thus the parameter.
--]]
function QuestTracker:UpdateTreeExclusitivity(exclusitivityTable)
	local tree 						= self.navigationTree
	local isTreeExclusive 			= tree.exclusive
	local newExclusitivityTable 	= exclusitivityTable or self.svCurrent.nodeExclusitivity
	local shouldTreeBeExclusive		= newExclusitivityTable.isTreeExclusive
	
	-- If the tree is already exclusive, other nodes are already closed, so we don't need to worry about
	-- closing categories or quest nodes, just set the new exclusitivity (if needed)
	if isTreeExclusive then
		if not shouldTreeBeExclusive then
			tree:SetExclusive(false)
		end
		
	else
		-- Tree is not currently exclusive. If it should be, set it exclusive & close all nodes
		if shouldTreeBeExclusive then
			local curSelectedNode 	= tree.selectedNode
			
			tree:SetExclusive(true)
			
			if curSelectedNode then
				-- exclusivePath has not been set yet, when SetExclusive is false it does not set the path
				-- so call OpenNode (even though it may already be open) to force it to set the path 
				-- and run exclusivitity close function after we set exclusive to true
				tree:SetNodeOpen(curSelectedNode, true, USER_REQUESTED_OPEN)
			end
			
		else
			-- Tree is not exclusive & should not be, dont change exclusitivity, but since tree is not exclusive
			-- category/quest nodes may be open that are not supposed to be. Check & update their exclusitivity.
			if newExclusitivityTable.categoryNodes then
				self:CloseAllCategoryNodes()
			end
			if newExclusitivityTable.questNodes then
				self:CloseAllQuestNodes()
			end
		end
	end
end

-- Update saved vars with new exclusitivity info
function QuestTracker:SetTreeExclusitivity(exclusiveName)
	local exclusitivity = {
		["None"] = {
			currentSetting	= "None",
			allNodes 		= false,
			categoryNodes 	= false,
			questNodes 		= false,
			isTreeExclusive	= false,
		},
		["All"] = {
			currentSetting	= "All",
			allNodes 		= true,
			categoryNodes 	= false,
			questNodes 		= false,
			isTreeExclusive	= true,
		},
		["Categories Only"] = {
			currentSetting	= "Categories Only",
			allNodes 		= false,
			categoryNodes 	= true,
			questNodes 		= false,
			isTreeExclusive	= false,
		},
		["Quests Only"] = {
			currentSetting	= "Quests Only",
			allNodes 		= false,
			categoryNodes 	= false,
			questNodes 		= true,
			isTreeExclusive	= false,
		},
	}
	local tree 					= self.navigationTree
	local newExclusitivity 		= exclusitivity[exclusiveName]
	self.svCurrent.nodeExclusitivity 	= newExclusitivity
	
	self:UpdateTreeExclusitivity(newExclusitivity)
	
	-- Make sure it scrolls back into view, just incase
	self:RefreshSelectedQuest()
end

--=========================================================--
--=========================================================--
--======================  TREE CODE  ======================--
--=========================================================--
--=========================================================--
-- I would strongly suggest you don't mess with any of this InitializeTree code.
-- The games tree class does not do everything I needed it to do. Like selecting nodes that have children.
-- So I changed some stuff & manually called/did whatever I needed instead of using the ZO_Tree functions.
-- There are several tree functions that you can NOT use. Some just wont work & some will mess things up.
function QuestTracker:InitializeTree()
    local navigationTree = self.navigationTree
	
    local openTexture 		= "EsoUI/Art/Buttons/tree_open_up.dds"
    local closedTexture 	= "EsoUI/Art/Buttons/tree_closed_up.dds"
    local overOpenTexture 	= "EsoUI/Art/Buttons/tree_open_over.dds"
    local overClosedTexture = "EsoUI/Art/Buttons/tree_closed_over.dds"
		
	--============ Category Node Code ============================================--
    local function CategoryNodeSetup(node, control, data, open, userRequested)
		local fontString 	= self:GetCategoryFontString()
		local textControl 	= control.text
		local icon			= control.icon
		local categoryName 	= data.name
		local numQuests 	= node.children and #node.children
		
		
		if numQuests and self.svCurrent.showNumCategoryQuests then
			categoryName = zo_strformat("[<<1>>] <<2>>", numQuests, categoryName)
		end
		
		node.label = textControl
		node.icon = icon
		
		textControl:SetFont(fontString)
        textControl:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        textControl:SetText(categoryName)
		
		local textWidth = textControl:GetTextWidth()
		local iconWidth = icon:GetWidth()
		node.textWidth = textWidth
		node.iconWidth = iconWidth
		
		-- if theres a problem with this, check the global UI scale
		node.totalControlWidth = textWidth + iconWidth + TEXT_LABEL_PADDING
		
		-- if theres a problem with this, check the global UI scale
		local textHeight 	= textControl:GetTextHeight()
		local currentHeight = control:GetHeight()
		
		if currentHeight ~= textheight then
			textControl:SetHeight(textHeight)
			control:SetHeight(textHeight)
			control.icon:SetDimensions(textHeight, textHeight)
			self:UpdateChildHeightsToRoot(node)
		end
		
		local categoryColor = ZO_ColorDef:New(unpack(self.svCurrent.fontSettings.categories.color))
		ZO_SelectableLabel_SetNormalColor(textControl, categoryColor)
		
        control.icon:SetTexture(open and openTexture or closedTexture)
        control.iconHighlight:SetTexture(open and overOpenTexture or overClosedTexture)
   
        textControl:SetSelected(open)
    end
	
    local function CategoryNodeEquality(left, right)
        return left.name == right.name
    end
    navigationTree:AddTemplate("QuestTrackerCategoryNode", CategoryNodeSetup, nil, CategoryNodeEquality, 40, 0)
	--============ End Category Node Code ========================================--
	
	--============ Quest Node Code ================================================--
	-- Shared code function for quest node setup & select
	-- Handles showing/hiding the quest selected or instance icon
	local function SetupQuestIcon(questNodeControl, nodeData, selected)
		local questNode		= questNodeControl.node
		local tree 			= questNode.tree
		local curQuestNode	= tree.selectedNode
        local icon 			= GetControl(questNodeControl, "Icon")
		
        icon.selected = selected
	
		if selected then
            icon:SetTexture("EsoUI/Art/Journal/journal_Quest_Selected.dds")
            icon:SetAlpha(1.00)
            icon:SetHidden(false)
			
		else
            icon:SetTexture(ZO_QUEST_JOURNAL_QUESTS_KEYBOARD:GetIconTexture(nodeData.displayType))
			icon.tooltipText = ZO_QUEST_JOURNAL_QUESTS_KEYBOARD:GetTooltipText(nodeData.displayType)
			
            if nodeData.displayType == INSTANCE_DISPLAY_TYPE_NONE then
                icon:SetHidden(true)
            else
                icon:SetAlpha(0.50)
                icon:SetHidden(true)   --   should be false ...  need to find changes in ESO source since DB DLC patch.   <------------------------------------------------------
            end
		end
	end
	
    local function QuestNodeSetup(questNode, questNodeControl, nodeData, open, userRequested)
		local questName			= nodeData.name
		local fontString		= self:GetQuestFontString()
		local textHeight 		= questNodeControl:GetTextHeight()
		local currentHeight 	= questNodeControl:GetHeight()
		local tree 				= self.navigationTree
		local selectedNode 		= tree.selectedNode
		local selected 			= false
		
		if self.svCurrent.showQuestLevel then
			questName = zo_strformat("[<<1>>] <<2>>", nodeData.level, questName)
		end
		
		--xxxxxx
		questNodeControl.con = GetCon(nodeData.level)
		questNodeControl.questIndex = nodeData.questIndex
		questNodeControl:SetFont(fontString)
		questNodeControl:SetText(questName)
		
		
		questNode.label = questNodeControl
		
		-- if theres a problem with this, check the global UI scale
		local textWidth = questNodeControl:GetTextWidth() + TEXT_LABEL_PADDING
		questNode.textWidth = textWidth
		questNode.totalControlWidth = textWidth
	
		-- if theres a problem with this, check the global UI scale
		if currentHeight ~= textheight then
			questNodeControl:SetHeight(textHeight)
			self:UpdateChildHeightsToRoot(questNode)
			questNodeControl.icon:SetDimensions(textHeight, textHeight)
		end
		
		if selectedNode and questNode == selectedNode then
			selected = true
		end
		
        questNodeControl:SetSelected(selected)
		SetupQuestIcon(questNodeControl, nodeData, selected)
		
		-- Used so we don't need to know if the control is selected or not, it 
		-- will refresh the correct color or set the default color, must be done after GetCon(...)
		questNodeControl:RefreshTextColor()
    end
	
	-- Handles closing nodes for node exclusitivity when a node is deselected, only called from
	-- QuestNodeOnSelected. Made a seperate function for simplicity only.
	local function DeselectQuestNode(questNode)
		local tree = questNode.tree
		
		-- If tree is exclusive it will handle closing nodes on its own
		if not tree.exclusive then
			local nodeExclusitivity 	= self.svCurrent.nodeExclusitivity
			
			-- If exclusive quest nodes, close the curQuestNode
			if nodeExclusitivity.questNodes then
				tree:SetNodeOpen(questNode, false, USER_REQUESTED_OPEN)
			end
			
			-- If exclusive category nodes & new quest is in a different category, close the current category node
			if nodeExclusitivity.categoryNodes then
				local questNodeParentNode = questNode.parentNode
				tree:SetNodeOpen(questNodeParentNode, false, USER_REQUESTED_OPEN)
			end
		end
	end
	
	-- The tree doesn't actually fire this because it has children...the game does not allow selecting nodes unless 
	-- they are leafs. I'm just defining it here with the others, and I will fire it manually myself through the node:OnSelected()
	--ZO_QUEST_JOURNAL_QUESTS_KEYBOARD:FireCallbacks("QuestSelected", data.questIndex) -- This is nothing, just a reminder about something
    local function QuestNodeOnSelected(questNodeControl, nodeData, selected, reselectingDuringRebuild)
		local questNode		= questNodeControl.node
		local tree 			= questNode.tree
		local curQuestNode	= tree.selectedNode
        local icon 			= GetControl(questNodeControl, "Icon")
		
		if selected then
			if curQuestNode and questNode ~= curQuestNode then
				tree:ClearSelectedNode()  -- calls :OnUnselected()
			end
			
			-- SetNodeOpen forces a call to questNode setup which deselects the node & hides the icon
			-- so we must do this before setting the icon, icon.selected, or control:SetSelected
			tree.selectedNode = questNode
			tree:SetNodeOpen(questNode, true, USER_REQUESTED_OPEN)
			
		else
			DeselectQuestNode(questNode)
		end
		
		-- must be done last, see comment above SetNodeOpen
        questNodeControl:SetSelected(selected)
		SetupQuestIcon(questNodeControl, nodeData, selected)
    end
	
    local function QuestNodeEquality(left, right)
        return left.name == right.name
    end
   -- navigationTree:AddTemplate("QuestTrackerQuestNode", QuestNodeSetup, QuestNodeOnSelected, QuestNodeEquality)
   -- ChildIndent & ChildSpacing are for the children "of this node" not for when this node is a child !
    navigationTree:AddTemplate("QuestTrackerQuestNode", QuestNodeSetup, QuestNodeOnSelected, QuestNodeEquality, 15, 0)
	--============ End Quest Node Code ============================================--
	
	--============ Condition Node Code ============================================--
    local function TreeConditionSetup(conditionNode, conditionNodeControl, data, open)
		local fontString = self:GetConditionFontString()
		
		conditionNode.label = conditionNodeControl
		
		conditionNodeControl:SetFont(fontString)
		conditionNodeControl:SetColor(unpack(self.svCurrent.fontSettings.conditions.color))
		conditionNodeControl:SetText(data.conditionText)
		
		-- if theres a problem with this, check the global UI scale
		local textWidth = conditionNodeControl:GetTextWidth() + TEXT_LABEL_PADDING
		conditionNode.textWidth = textWidth
		conditionNode.totalControlWidth = textWidth
	
		-- if theres a problem with this, check the global UI scale
		local textHeight 	= conditionNodeControl:GetTextHeight()
		local currentHeight = conditionNodeControl:GetHeight()
		
		if currentHeight ~= textheight then
			conditionNodeControl:SetHeight(textHeight)
			self:UpdateChildHeightsToRoot(conditionNode)
		end
    end
    navigationTree:AddTemplate("QuestTrackerConditionNode", TreeConditionSetup)
	--============ End Condition Node Code ========================================--
	
	-- true means only one can be open at a time AND you can't click to close it. You have to open another to get it to close. Just left as a reminder: navigationTree:SetExclusive(true/false)...but don't do (below) here. Or a node wont be selected yet & the exclusive path wont get set correctly.
	--self:UpdateTreeExclusitivity()
	
    navigationTree:SetOpenAnimation("ZO_TreeOpenAnimation")
	
	return navigationTree
end

--================================================================--
--================================================================--
--============ TREE RELEASE NODE CODE ============================--
--================================================================--
--================================================================--
function QuestTracker:ReleaseConditionNode(conditionNode)
	-- hide its highlight if it has it
	self:HideNodeSelectionHighlight(conditionNode)
	
	-- Release any animations it has
	self:ReleaseOpenAnimation(conditionNode)
	
	-- Get the objectPool for conditions & release the condition Node
	local conditionObjectPool = self.navigationTree.templateInfo["QuestTrackerConditionNode"].objectPool
	self:ReleaseNodeFromPool(conditionNode, conditionObjectPool)
end

function QuestTracker:ReleaseQuestNode(questNode)
	local tree 				= self.navigationTree
	local selectedNode 		= tree.selectedNode
	local siblingsTable		= questNode.parentNode.children
	local questIndex		= questNode.data.questIndex
	local categoryNode		= questNode.parentNode
	local next				= next
	
	-- Remove the quest node reference from the questIndexToTreeNode table
	tree.questIndexToTreeNode[questIndex] = nil
	
	if self:AreTreeNodesEqual(questNode, selectedNode) then
		tree.selectedNode = nil
	end
	
	-- Reanchor around the node to be removed
	self:AnchorPreviousNodeToNextNode(questNode)
	
	-- release all of the condition nodes
	self:ReleaseAllQuestConditionNodes(questNode)
	
	-- release all node objects including the node control, animations, child container, exc...
	local questObjectPool = tree.templateInfo["QuestTrackerQuestNode"].objectPool
	self:ReleaseNodeObjects(questNode, questObjectPool)
	
	-- If the siblingsTable is empty, there are no more quests under this category
	-- then, release the category node.
	if next(siblingsTable) == nil then
		self:ReleaseCategoryNode(categoryNode)
	end
end

function QuestTracker:ReleaseChildContainer(treeNode)
	local containerControlName 		= treeNode.childContainer:GetName()
	local containerObjectPool 		= self.navigationTree.childContainerPool
	local activeContainerObjects 	= containerObjectPool.m_Active
	
	for objKey,obj in pairs(activeContainerObjects) do
		if containerControlName == obj:GetName() then
			containerObjectPool:ReleaseObject(objKey)
		end
	end
	
	self:UpdateChildHeightsToRoot(treeNode)
end

function QuestTracker:ReleaseNodeFromPool(treeNode, objectPool)
	local activeCategoryObjects 	= objectPool.m_Active
	local CategoryNodeControlName 	= treeNode.control:GetName()
	local parentNode 				= treeNode.parentNode
	
	for objKey,obj in pairs(activeCategoryObjects) do
		if CategoryNodeControlName == obj:GetName() then
			objectPool:ReleaseObject(objKey)
		end
	end
	
	self:UpdateChildHeightsToRoot(parentNode)
end

function QuestTracker:HideNodeSelectionHighlight(treeNode)
    if(treeNode.selectionHighlight) then
        treeNode.selectionHighlight:SetHidden(true)
    end
end

function QuestTracker:ReleaseOpenAnimation(treeNode)
	self.navigationTree.openAnimationPool:ReleaseObject(treeNode)
end

function QuestTracker:ReleaseNodeObjects(treeNode, nodeObjectPool)
	-- Get the parentNode.children table index for the node to be removed
	local treeNodeTableIndex 	= self:GetNodeTableIndex(treeNode)
	local siblingTable			= treeNode.parentNode.children
	
	-- release the nodes child container
	self:ReleaseChildContainer(treeNode)
	
	self:HideNodeSelectionHighlight(treeNode)
	self:ReleaseOpenAnimation(treeNode)

	-- Release the category node itself
	self:ReleaseNodeFromPool(treeNode, nodeObjectPool)
	
	-- This is done here because the node referenced in this table, at this index,
	-- is no longer a valid node, we just released all of its objects
	-- Remove the node from the treeNode.parentNode.children table
	table.remove(siblingTable, treeNodeTableIndex)
	
	self:UpdateChildHeightsToRoot(treeNode)
end

function QuestTracker:ReleaseCategoryNode(categoryNode)
	local tree 				= self.navigationTree
	local rootNode			= tree.rootNode
	local rootChildren		= rootNode.children
	
	-- Reanchor around the node to be removed
	self:AnchorPreviousNodeToNextNode(categoryNode)
	
	-- release all of the quest nodes
	self:ReleaseAllCategoryQuestNodes(categoryNode)
	
	-- Release all node objects, for the category node
	local categorytObjectPool = tree.templateInfo["QuestTrackerCategoryNode"].objectPool
	self:ReleaseNodeObjects(categoryNode, categorytObjectPool)
	
	self:UpdateChildHeightsToRoot(rootNode)
end

-- release all of the quest nodes, 
function QuestTracker:ReleaseAllCategoryQuestNodes(categoryNode)
	local categoryChildren = categoryNode.children
	
	-- children can be nil if no quests, so check it first
	if type(categoryChildren) == "table" then
		for k,questNode in pairs(categoryChildren) do
			self:ReleaseQuestNode(questNode)
		end
	end
	-- nil the child table & update heights to root
	categoryNode.children = nil
	self:UpdateChildHeightsToRoot(categoryNode)
end

-- release all of the condition nodes, can be nil if no conditions
function QuestTracker:ReleaseAllQuestConditionNodes(questNode)
	local questConditions = questNode.children
	
	-- children can be nil if no quests, so check it first
	if type(questConditions) == "table" then
		for k,conditionNode in pairs(questConditions) do
			self:ReleaseConditionNode(conditionNode)
		end
	end
	-- nil the child table & update heights to root
	questNode.children = nil
	self:UpdateChildHeightsToRoot(questNode)
end
--============ END TREE RELEASE NODE CODE ============================--


--========================================================--
--=================   XML CODE/Functions =================--
--========================================================--

--================================================================--
--==================== XML: Main Window Code  ====================--
--================================================================--
local function ResetAnchorPosition(self)
    local left = self:GetLeft()
    local top = self:GetTop()
    self:ClearAnchors()
    self:SetAnchor(TOPLEFT, nil, TOPLEFT, left, top)
end

local function QuestTracker_On_ResizeStop(self)
    QUESTTRACKER.svCurrent.mainWindow.width    = self:GetWidth()
    QUESTTRACKER.svCurrent.mainWindow.height    = self:GetHeight()
    
    QUESTTRACKER.questTreeWin:SetDimensionConstraints(CONSTRAINT_WIDTH, CONSTRAINT_HEIGHT, 0, 0)
end

local function QuestTracker_On_ResizeStart(self)
    local currentWidth	= self:GetWidth()
    local currentHeight	= self:GetHeight()
    
    local autoSizeHeight	= QUESTTRACKER.svCurrent.mainWindow.autoWindowSizeHeight
    local autoSizeWidth		= QUESTTRACKER.svCurrent.mainWindow.autoWindowSizeWidth
    
    local minWidth 	= autoSizeWidth	 and currentWidth  or CONSTRAINT_WIDTH
    local maxWidth	= autoSizeWidth	 and currentWidth  or 0
    local minHeight = autoSizeHeight and currentHeight or CONSTRAINT_HEIGHT
    local maxHeight	= autoSizeHeight and currentHeight or 0
    
    QUESTTRACKER.questTreeWin:SetDimensionConstraints(minWidth, minHeight, maxWidth, maxHeight)
end

local function QuestTracker_On_MoveStop(self)
    QUESTTRACKER.svCurrent.mainWindow.offsetX = self:GetLeft()
    QUESTTRACKER.svCurrent.mainWindow.offsetY = self:GetTop()
    ResetAnchorPosition(self)
end

function QuestTracker_QuestTree_OnInitialized(self)
    self:SetHandler("OnResizeStart", 	QuestTracker_On_ResizeStart)
    self:SetHandler("OnResizeStop",		QuestTracker_On_ResizeStop)
    self:SetHandler("OnMoveStop",		QuestTracker_On_MoveStop)
end

function QuestTracker:SetResizeHandleSize(autoResize)
    if autoResize then
        self.questTreeWin:SetResizeHandleSize(0)
        return
    end
    self.questTreeWin:SetResizeHandleSize(6)
end

--================================================================--
--=================== XML: Category Node Code  ===================--
--================================================================--
local function CategoryNode_OnMouseUp(self, button, upInside)
	if not upInside then return end
	ZO_TreeHeader_OnMouseUp(self, upInside)
	
	-- we only have to worry about closing category nodes when "Categories Only" exclusitivity is turned on. 
	-- other code handles closing them when exclusive is set to "All"
	-- When a quest is selected by forceAssist, the questNode 
	-- :OnSelected() [QuestNodeOnSelected() -> DeselectQuestNode()]
	-- handles closing category nodes for "Categories Only" exclusitivity
	if not QUESTTRACKER.svCurrent.nodeExclusitivity.categoryNodes then return end
	
	local tree 			= QUESTTRACKER.navigationTree
	local rootChildren	= tree.rootNode.children
	local clickedNode	= self.node
	
	for _, categoryNode in pairs(rootChildren) do
		if categoryNode.open and not QUESTTRACKER:AreTreeNodesEqual(clickedNode, categoryNode) then
			tree:SetNodeOpen(categoryNode, false, USER_REQUESTED_OPEN)
		end
	end
end

function QuestTracker_CategoryNode_OnInitialized(self)
	self.icon 			= self:GetNamedChild("Icon")
	self.iconHighlight 	= self.icon:GetNamedChild("Highlight")
	self.text			= self:GetNamedChild("Text")
	
	-- do not try to change this & use SetHandler !!
	self.OnMouseUp 		= CategoryNode_OnMouseUp
end

--=================================================================--
--===================== XML: Quest Node Code  =====================--
--=================================================================--
-- Used for special override of con color in quest nodes
-- ZO_SelectableLabel_OnInitialized(self, QuestTracker_QuestNode_GetTextColor),  instead of:
-- ZO_SelectableLabel_OnInitialized(self, ZO_QuestJournalNavigationEntry_GetTextColor)
function QuestTracker_QuestNode_GetTextColor(self)
    if self.selected then
        return GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED)
    elseif self.mouseover  then
        return GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_HIGHLIGHT)		
    elseif QUESTTRACKER and QUESTTRACKER.svCurrent.overrideConColors then		
		return unpack(QUESTTRACKER.svCurrent.fontSettings.quests.color)		
	else
        return GetColorForCon(self.con)
    end
end

local function QuestNode_OnMouseUp(self, button, upInside)
	if not upInside then return end
	
	if button == MOUSE_BUTTON_INDEX_LEFT then
		local questIndex = self.node.data.questIndex
		
		ZO_TreeHeader_OnMouseUp(self, upInside)
		
		-- We don't need to fire self.node:OnSelected() it will cause a double call to OnSelected()
		-- Update the journal panel & force assist (which will fire the assist callback & call node:OnSelected())
		ZO_QUEST_JOURNAL_QUESTS_KEYBOARD:FocusQuestWithIndex(questIndex)
		FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
		
	elseif button == MOUSE_BUTTON_INDEX_RIGHT then
		ClearMenu()
		AddCustomMenuItem("Share Quest", function() 
			local questIndex = self.node.data.questIndex
			ShareQuest(questIndex) 
		end)
		AddCustomMenuItem("Show On Map", function() 
			local questIndex = self.node.data.questIndex
			ZO_WorldMap_ShowQuestOnMap(questIndex)
		end)
		AddCustomMenuItem("Abandon Quest", function()
			local questIndex = self.node.data.questIndex
			AbandonQuest(questIndex)
		end)
		ShowMenu()
	end
end

local function QuestNode_OnMouseEnter(self)
	if not QUESTTRACKER.svCurrent.tooltips.show then return end
	if QUESTTRACKER.WINDOW_FRAGMENT:IsHidden() then return end
	
	local questIndex = self.node.data.questIndex
	QUESTTRACKER:ShowQuestTooltip(questIndex)
end

local function QuestNode_OnMouseExit(self)
	-- This is just to let you know, don't do this. Its not necessary. 
	-- OnMouseEnter calls ShowQuestTooltip, which unregisters there, so by the time OnMouseExit gets called
	-- this update has already been unregistered.
	--EVENT_MANAGER:UnregisterForUpdate("QuestTrackerClearAutoTooltip")
	ClearTooltip(InformationTooltip)
end

function QuestTracker_QuestNode_OnInitialized(self)
	self.icon 			= self:GetNamedChild("Icon")
	self.iconHighlight 	= self.icon:GetNamedChild("Highlight")
	self.text			= self:GetNamedChild("Text")

	-- do not try to change this & use SetHandler !!
	self.OnMouseUp 		= QuestNode_OnMouseUp
	self.OnMouseEnter 	= QuestNode_OnMouseEnter
	self.OnMouseExit 	= QuestNode_OnMouseExit
end

--================================================================--
--=================== XML: Lock/Unlock Buttons ===================--
--================================================================--
function QuestTracker_LockButton_OnMouseUp(self, button, upInside)
	if not upInside then return end
	
	QUESTTRACKER:SetLockState(false)
end

function QuestTracker_UnlockButton_OnMouseUp(self, button, upInside)
	if not upInside then return end
	
	QUESTTRACKER:SetLockState(true)
end

-------------------------------------------------------------------
--  OnAddOnLoaded  --
-------------------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
	if addonName == ADDON_NAME then
		QUESTTRACKER = QuestTracker:New()
		-- Since QuestTracker_QuestNode_GetTextColor(...) is called from xml on initialization
        -- We must refresh the tree in case they have overridden the quest con colors
        -- to get it to update the quest con colors
		QUESTTRACKER.navigationTree:RefreshVisible()
	end
end

---------------------------------------------------------------------
--  Register Events --
---------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

---------------------------------------------------------------------
--  Slash Commands --
---------------------------------------------------------------------
--SLASH_COMMANDS["/QuestTracker"] 		= QuestTracker_ToggleMainWindow

--[[
SLASH_COMMANDS["/qto"] = function() 
    if QUESTTRACKER.svCurrent.nodeExclusitivity.currentSetting ~= "None" then
        local darkOrange = "FFA500"
        local msg = zo_strformat("|c<<1>><<2>>:|r <<3>>", darkOrange, "QUESTTRACKER", "AutoClose must be turned OFF for open nodes to work")
        d(msg)
        return
    end
    QUESTTRACKER:OpenAllQuestNodes()
end
--]]

-- Toggle window visible
SLASH_COMMANDS["/qth"] = QuestTracker_ToggleWindow

-- Toggle Quests open/close
SLASH_COMMANDS["/qta"] = function()
--
    if QUESTTRACKER.svCurrent.nodeExclusitivity.currentSetting ~= "None" then
        local darkOrange = "FFA500"
        local msg = zo_strformat("|c<<1>><<2>>:|r <<3>>", darkOrange, "QUESTTRACKER", "AutoClose must be turned OFF for open nodes to work")
        d(msg)
        return
    else
--]]
		if QUESTTRACKER.svCurrent.autoOpenNodes then
			QUESTTRACKER.svCurrent.autoOpenNodes = false
			QUESTTRACKER:CloseAllQuestNodes()
		else
			QUESTTRACKER.svCurrent.autoOpenNodes = true
			QUESTTRACKER:OpenAllQuestNodes()
		end
	end
end

-- Toggle lock/unlock window
SLASH_COMMANDS["/qtl"] = function()
	local lock = false	
	if QUESTTRACKER.svCurrent.mainWindow.locked then
		QUESTTRACKER.svCurrent.mainWindow.locked = false
		lock = false
	else QUESTTRACKER.svCurrent.mainWindow.locked = true 
		lock = true
	end			
	QuestTracker:SetLockState(lock) 
end

-- Open all Quests in selected category and collapse all others.
SLASH_COMMANDS["/qts"] = function()
	QuestTracker:CloseAllCategoryNodes()
	QUESTTRACKER:OpenSelectedCategoryQuestNodes()
	QUESTTRACKER.navigationTree:RefreshVisible()
end

-- Help Menu
SLASH_COMMANDS["/qt"] = function(text)
	if not text or text == "" or text == "help" or text == "?" then
		d(colorRavalox.."[QuestTracker]"..colorYellow.." Accepted Commands:")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt"..colorSoftYellow.." << shows this help")
		--d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt list"..colorSoftYellow.." << lists all tracked quests")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt help"..colorSoftYellow.." << shows help")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt settings"..colorSoftYellow.." << shows QuestTracker settings menu")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/questtracker"..colorSoftYellow.." << shows QuestTracker settings menu")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qth"..colorSoftYellow.." << hide QuestTracker UI toggle")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qta"..colorSoftYellow.." << Toggle open/close all quest nodes")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt1"..colorSoftYellow.." << Toggle lock/unlock QuestTracker window")
		d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qts"..colorSoftYellow.." << opens all quests in current category")
		--d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt help abandon"..colorSoftYellow.." << shows abandon quest help")
		--d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt help share"..colorSoftYellow.." << shows share quest help")
		--d(colorRavalox.."[QuestTracker]"..colorCMDBlue.."/qt help track"..colorSoftYellow.." << shows track quest help")
		--d(colorRavalox.."[QuestTracker]"..colorSoftYellow.." To EDIT White and Black lists, please edit your /SavedVariables/MQTuestTools.lua file.")
		return
	end

	if text == "settings" then
		local LAM2 = LibAddonMenu2
		LAM2:OpenToPanel(QUESTTRACKER.addonPanel)
	end

	--[[  
		-- Slash commands to possibly support from Wykkyd's Version
		self:SlashCommand("qta", _addon.Abandon)		--Abandon a quest by index #  will show index list if # omitted
		self:SlashCommand("qtbl", _addon.BlackList)		--not sure
		self:SlashCommand("qts", _addon.Share)			--share a quest by index #  will show index list if # omitted
		self:SlashCommand("qtwl", _addon.WhiteList)		--not sure
		self:SlashCommand("qtt", _addon.Track)			--focus a specific quest (by index #)  qtt with no # will list index list
	--]]
end