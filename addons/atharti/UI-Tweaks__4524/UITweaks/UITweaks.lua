UITweaks = {}

local UIT = UITweaks
local EM = EVENT_MANAGER

UIT.name = "UITweaks"

local defaultSV = {
	CleanAchievementText = false,
	ChatLinkEnabled = false,
	BigMapEnabled = false,
	HideSwap = false,
	RollRawlkhaEnabled = false,
	ZoomEnabled = false,
	HideStealth = false,
	ContainerOpenerEnabled = false,
	NoQuitGuild = false,
	FullScreenToggle = false,
	HideKeyStripBackdrop = false,
	HideKeyStripAdvisor = false,
	HideMarket = false,
	HideDirections = false,
	CursorFix = false,
	ReloadUI = false,
	enlightenmentOff = false,
	hideMorag = false,
	hideImperial = false,
	hideHelp = false,
	hideDestroy = false,
	hideJunk = false,
	--AutoClaimLevelUpRewards = true,
	cleanAntiqTool = false,
	visitPlayer = false,
	dontStopInteraction = false,
	disableGroupAreaPopup = false,
}
-- =========================================================
function UIT.CleanAchievement()
	if not UIT.SV.CleanAchievementText then return end
	SafeAddString(SI_ACHIEVEMENT_EARNED_FORMATTER, "", 2)
end
-- =========================================================
function UIT.InsertItemLink(inventorySlot)
	local components = ZO_InventorySlot_GetInventorySlotComponents(inventorySlot)
	local itemLink = GetItemLink(components.bagId, components.slotIndex, LINK_STYLE_BRACKETS)
	if itemLink then
		ZO_LinkHandler_InsertLink(itemLink)
	end
end

function UIT.SetupChatLink()
	SecurePostHook("ZO_InventorySlot_OnSlotClicked", function(inventorySlot, button)
		if button == MOUSE_BUTTON_INDEX_LEFT and IsShiftKeyDown() then
			UIT.InsertItemLink(inventorySlot)
		end
	end)
end
-- =========================================================
function UIT.SetupBigMap()

	local supportedMapModes = {
		[MAP_MODE_LARGE_CUSTOM] = true,
		[MAP_MODE_KEEP_TRAVEL] = true,
		[MAP_MODE_FAST_TRAVEL] = true,
		[MAP_MODE_AVA_RESPAWN] = true,
		[MAP_MODE_AVA_KEEP_RECALL] = true,
		[MAP_MODE_DIG_SITES] = true,
		[MAP_MODE_SMALL_CUSTOM] = true,
	}

	local mapController = ZO_WorldMap_GetPanAndZoom()

	local function adjustMapDimensions()
		local isMapVisible = WORLD_MAP_SCENE:IsShowing()
		local currentMode = WORLD_MAP_MANAGER:GetMode()

		if isMapVisible and supportedMapModes[currentMode] then
			ZO_WorldMap:ClearAnchors()
			ZO_WorldMap:SetAnchor(TOP, GuiRoot, TOP, 60, 80)
			ZO_WorldMap:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 60, -70)

			local setSize = ZO_WorldMap:GetHeight()
			local currentZoomLevel = mapController:GetCurrentNormalizedZoom()

			ZO_WorldMap:SetDimensions(setSize, setSize)
			ZO_WorldMapScroll:SetDimensions(setSize, setSize)

			mapController:SetCurrentNormalizedZoomInternal(currentZoomLevel)
		end
	end

	local function onMapStateChanged(oldState, newState)
		if newState == SCENE_SHOWING then
			zo_callLater(adjustMapDimensions, 0)
		end
	end

	local function onScreenResized()
		adjustMapDimensions()
	end

	-- Hook into map mode changes
	local originalSetMode = WORLD_MAP_MANAGER.SetMode
	function WORLD_MAP_MANAGER:SetMode(mode, ...)
		originalSetMode(self, mode, ...)
		adjustMapDimensions()
	end

	local originalMapUpdate = ZO_WorldMap_UpdateMap
	local originalAnchorRefresh = ZO_WorldMap_RefreshMapFrameAnchor

	function ZO_WorldMap_UpdateMap()
		originalMapUpdate()
		adjustMapDimensions()
	end

	function ZO_WorldMap_RefreshMapFrameAnchor(...)
		if WORLD_MAP_SCENE:IsShowing() and supportedMapModes[WORLD_MAP_MANAGER:GetMode()] then
			return
		end
		return originalAnchorRefresh(...)
	end

	WORLD_MAP_SCENE:RegisterCallback("StateChange", onMapStateChanged)
	ZO_WorldMap:RegisterForEvent(EVENT_SCREEN_RESIZED, onScreenResized)

	if WORLD_MAP_SCENE:IsShowing() then
		adjustMapDimensions()
	end
end
-- =========================================================
function UIT.HideWeaponSwapIcon()
	ZO_ActionBar1WeaponSwap:SetAlpha(0)
end
-- =========================================================
function UIT.Mundus()
	ZO_CharacterWindowStatsScrollScrollChildZO_MundusStonesStatsEntryHeader:SetFont(('$(BOLD_FONT)|$(KB_%d)|soft-shadow-thin'):format(16))
end
-- =========================================================
local QUESTS_TO_ABANDON = {
	[5837] = true,
	[5856] = true,
	[5852] = true,
	[5845] = true,
	[5838] = true,
	[5839] = true,
	[5811] = true,
	[5855] = true,
}

local autoAbandonEnabled = true

function UIT.OnQuestAdded(eventCode, journalQuestIndex, questName, objectiveName)
	local questId = GetJournalQuestId(journalQuestIndex)

	if questId == 5834 then
		d("|cFFFFFFRawlkha Rolled!|r")
	end

	if autoAbandonEnabled and QUESTS_TO_ABANDON[questId] then
		if CanAbandonJournalQuest(journalQuestIndex) then
			AbandonQuest(journalQuestIndex)
		else
			d(string.format("|c88CCFF[RollRawlkha]|r Cannot abandon quest |cFF0000%s|r", questName))
		end
	end
end
-- =========================================================
function UIT.SetCameraZoom()
	local ZOOM_MIN = 2
	local ZOOM_FPV = 0
	local ZOOM_STEP = 0.5

	local savedZoom = tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))

	local function IsZoomLimited()
		return IsMounted() or IsWerewolf()
	end

	local origToggleGameCameraFirstPerson = ToggleGameCameraFirstPerson
	ToggleGameCameraFirstPerson = function(...)
		local zoom = tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
		if zoom <= ZOOM_FPV then
			SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, savedZoom)
		elseif not IsZoomLimited() then
			savedZoom = zoom
			origToggleGameCameraFirstPerson(...)
		else
			origToggleGameCameraFirstPerson(...)
		end
	end

	local origCameraZoomIn = CameraZoomIn
	CameraZoomIn = function(...)
		local zoom = tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
		if IsGameCameraSiegeControlled() or zoom > ZOOM_MIN then
			origCameraZoomIn(...)
		else
			local newZoom = zo_max(zoom - ZOOM_STEP, ZOOM_FPV)
			if newZoom < zoom then
				savedZoom = zoom
				SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, newZoom)
			end
		end
	end

	local origCameraZoomOut = CameraZoomOut
	CameraZoomOut = function(...)
		local zoom = tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
		if IsGameCameraSiegeControlled() or zoom >= ZOOM_MIN then
			origCameraZoomOut(...)
		else
			SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, zoom + ZOOM_STEP)
		end
	end

	EM:RegisterForEvent(UIT.name .. "_CameraZoom", EVENT_PLAYER_ACTIVATED, function()
		SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, savedZoom)
	end)
end
-- =========================================================
function UIT.SetHideStealth()
	local stealthText = WINDOW_MANAGER:GetControlByName("ZO_ReticleContainerStealthIconStealthText")
	stealthText:SetText("")
end

-- =========================================================
local SPECIFIC_ITEM_IDS = {
	[69413] = true,
}

function UIT.OpenContainers()
	local function processNext()
		if GetNumBagFreeSlots(INVENTORY_BACKPACK) <= 0 then
			d("|cFFD700[UI Tweaks]|r |cFF4444Bag is full!|r")
			return
		end

		local inventoryCount = GetBagSize(INVENTORY_BACKPACK)

		for x = 0, inventoryCount - 1 do
			local link = GetItemLink(INVENTORY_BACKPACK, x)

			if link and link ~= "" then
				local itemId = GetItemId(INVENTORY_BACKPACK, x)
				local itemType = GetItemLinkItemType(link)

				if itemType == ITEMTYPE_CONTAINER or SPECIFIC_ITEM_IDS[itemId] then
					CallSecureProtected("UseItem", INVENTORY_BACKPACK, x)

					zo_callLater(function()
						LootAll()
						processNext()
					end, 800)

					return
				end
			end
		end
	end

	processNext()
end

function UITweaks_Open()
	UIT.OpenContainers()
end
-- =========================================================
function UIT.GuildQuitButton()
	GUILD_HOME.keybindStripDescriptor[1].visible = function() return false end
end

-- =========================================================
function UITweaks_Fullscreen()
	local current = tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN))

	if current == 1 then
		SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN, 2)
		d("|cFFD700[UI Tweaks]|r |cFFFFFFFullscreen|r")
		return
	end

	if current == 2 then
		SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN, 1)
		d("|cFFD700[UI Tweaks]|r |cFFFFFFBorderless|r")
		return
	end
end
-- =========================================================
function UIT.HideBackDrop()
	ZO_KeybindStripMungeBackgroundTexture:SetHidden(true)
end

-- =========================================================
function UIT.HideAdvisor()
	SKILLS_WINDOW.keybindStripDescriptor[5].visible = function() return false end
end
-- =========================================================
function UIT.HideMarketUI()
	local UI = {
		"ZO_AdvZoneHUDTrackerContainer",
		"ZO_AdvZoneHUD_TopLevel",
	}

	for _, name in ipairs(UI) do
		local obj = GetControl(name)
		   ZO_PreHookHandler(obj, "OnShow", function()
			   obj:SetHidden(true)
		   end)
		   obj:SetHidden(true)
	end
end
-- =========================================================
function UIT.HideCompassDirections()
	COMPASS.container:SetCardinalDirection("", "", CARDINAL_DIRECTION_NORTH)
	COMPASS.container:SetCardinalDirection("", "", CARDINAL_DIRECTION_EAST)
	COMPASS.container:SetCardinalDirection("", "", CARDINAL_DIRECTION_WEST)
	COMPASS.container:SetCardinalDirection("", "", CARDINAL_DIRECTION_SOUTH)
end
-- =========================================================
function UIT.CursorFix()
	ZO_PreHook(SCENE_MANAGER, 'OnChatInputStart', function(self)
		self.exitUIModeOnChatFocusLost = false
		if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_RETURN_CURSOR_ON_CHAT_FOCUS) and IsGameCameraActive() then
			if not self:IsInUIMode() and SCENE_MANAGER:IsShowingBaseScene() then
				self:SetInUIMode(true)
				self:ShowBaseScene()
				ShowMouse(false)

				self:CallWhen(self.hudUISceneName, SCENE_HIDDEN, function()
					if self.exitUIModeOnChatFocusLost then
						ShowMouse(true)
						self.exitUIModeOnChatFocusLost = false
					end
				end)

				self.exitUIModeOnChatFocusLost = true
			end
		end

		return true
	end)
end

-- =========================================================
function UIT.DisableEnlightenment()
	local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()

	ZO_PreHook(handlers, EVENT_ENLIGHTENED_STATE_GAINED, function() return true end)
	ZO_PreHook(handlers, EVENT_ENLIGHTENED_STATE_LOST,	 function() return true end)
	ZO_PreHook(handlers, EVENT_PLAYER_ACTIVATED,		 function() return true end)
end

-- =========================================================
function UIT.DisableContextMenuAction(actionStringId)
	ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction", function(self, actionId)
		if actionId == actionStringId then
			return true
		end
	end)
end

-- =========================================================
-- function UIT.OnLevelUpRewardUpdated()
	-- local pendingRewards = ZO_LEVEL_UP_REWARDS_MANAGER:GetPendingLevelUpRewards()
	-- if not pendingRewards then return end

	-- for _, entryInfo in ipairs(pendingRewards) do
		-- if entryInfo.choices then
			-- MakeLevelUpRewardChoice(entryInfo.rewardId, entryInfo.choices[1].rewardId)
		-- end
	-- end

	-- ClaimPendingLevelUpReward()
-- end
-- =========================================================
function UIT.CleanUpAntiq()
	SafeAddString(SI_ANTIQUITIES_DIG_SITE_EYE_PROMPT_DESCRIPTION, "", 2)

	ZO_PreHook(ZO_PlayerToPlayer, "ShouldShowDecline", function(self, incomingEntry)
		if incomingEntry and incomingEntry.incomingType == ZO_INTERACT_TYPE.DIG_SITE_EYE then
			return true, false
		end
	end)
end

-- =========================================================
function UIT.slashVisit()
	SLASH_COMMANDS["/visit"] = function(cmd)
		local player = string.match(cmd, "(@%S+)")
		if player then
			JumpToHouse(player)
		end
	end
end

-- =========================================================
function UIT.NoInterrupt()
	ZO_PreHook(END_IN_WORLD_INTERACTIONS_FRAGMENT, "Show", function(self)
		EndPendingInteraction()
		self:OnShown()
		return true
	end)
end

-- =========================================================
function UIT.SuppressGroupZone()
	local lang = GetCVar("language.2")

	local entering, leaving
	if lang == "de" then
		entering = "Ihr habt einen Bereich für Gruppen betreten."
		leaving	 = "Ihr habt den Bereich für Gruppen verlassen."
	elseif lang == "fr" then
		entering = "Vous entrez dans une zone de groupe."
		leaving	 = "Sortie de la zone de groupe."
	elseif lang == "ru" then
		entering = "Вы входите в групповую область."
		leaving	 = "Вы покидаете групповую область."
	elseif lang == "zh" then
		entering = "您正在进入组队区域."
		leaving	 = "您即将离开组队区域."
	else
		entering = "Entering Group Area."
		leaving	 = "Leaving Group Area."
	end

	local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()

	local function HookGroupZoneMessages(primaryText, secondaryText)
		return primaryText == entering or primaryText == leaving
			or secondaryText == entering or secondaryText == leaving
	end

	ZO_PreHook(handlers, EVENT_DISPLAY_ANNOUNCEMENT, HookGroupZoneMessages)
end


-- =========================================================
-- Initialization
-- =========================================================
function UIT.Initialize()
	UIT.SV = ZO_SavedVars:NewAccountWide("UITweaks_SV", 1, nil, defaultSV)
	UIT.RegisterLAMPanel()

	if UIT.SV.CleanAchievementText then
		UIT.CleanAchievement()
	end

	if UIT.SV.ChatLinkEnabled then
		UIT.SetupChatLink()
	end

	if UIT.SV.BigMapEnabled then
		UIT.SetupBigMap()
	end

	if UIT.SV.HideSwap then
		UIT.HideWeaponSwapIcon()
	end

	UIT.Mundus()

	if UIT.SV.RollRawlkhaEnabled then
		EM:RegisterForEvent(UIT.name .. "_RollRawlkha", EVENT_QUEST_ADDED, UIT.OnQuestAdded)
	end

	if UIT.SV.ZoomEnabled then
		UIT.SetCameraZoom()
	end

	if UIT.SV.HideStealth then
		EM:RegisterForEvent(UIT.name .. "_StealthText", EVENT_STEALTH_STATE_CHANGED, UIT.SetHideStealth)
		UIT.SetHideStealth()
	end

	if UIT.SV.ContainerOpenerEnabled then
		ZO_CreateStringId("SI_BINDING_NAME_UITWEAKS_CONTAINERS", "Open All Containers")
	end

	if UIT.SV.NoQuitGuild then
		UIT.GuildQuitButton()
		ZO_PreHook(GUILD_HOME, "RefreshAll", UIT.GuildQuitButton)
	end

	if UIT.SV.FullScreenToggle then
		ZO_CreateStringId("SI_BINDING_NAME_UITWEAKS_FULLSCREEN", "Toggle Fullscreen/Borderless")
	end

	if UIT.SV.HideKeyStripBackdrop then
		UIT.HideBackDrop()
	end

	if UIT.SV.HideKeyStripAdvisor then
		UIT.HideAdvisor()
	end

	if UIT.SV.HideMarket then
		UIT.HideMarketUI()
	end

	if UIT.SV.HideDirections then
		UIT.HideCompassDirections()
	end

	if UIT.SV.CursorFix then
		UIT.CursorFix()
	end

	if UIT.SV.ReloadUI then
		ZO_CreateStringId("SI_BINDING_NAME_UITWEAKS_RELOAD", "Reload UI")
	end

	if UIT.SV.enlightenmentOff then
		UIT.DisableEnlightenment()
	end

	if UIT.SV.hideMorag then
		UIT.DisableContextMenuAction(SI_ITEM_ACTION_CONVERT_TO_MORAG_TONG_STYLE)
	end

	if UIT.SV.hideImperial then
		UIT.DisableContextMenuAction(SI_ITEM_ACTION_CONVERT_TO_IMPERIAL_STYLE)
	end

	if UIT.SV.hideHelp then
		UIT.DisableContextMenuAction(SI_ITEM_ACTION_REPORT_ITEM)
	end

	if UIT.SV.hideDestroy then
		UIT.DisableContextMenuAction(SI_ITEM_ACTION_DESTROY)
	end

	if UIT.SV.hideJunk then
		UIT.DisableContextMenuAction(SI_ITEM_ACTION_MARK_AS_JUNK)
	end

	-- if UIT.SV.AutoClaimLevelUpRewards then
		-- EM:RegisterForEvent(UIT.name, EVENT_LEVEL_UP_REWARD_UPDATED, UIT.OnLevelUpRewardUpdated)
	-- end

	if UIT.SV.cleanAntiqTool then
		UIT.CleanUpAntiq()
	end

	if UIT.SV.visitPlayer then
		UIT.slashVisit()
	end

	if UIT.SV.dontStopInteraction then
		UIT.NoInterrupt()
	end

	if UIT.SV.disableGroupAreaPopup then
		UIT.SuppressGroupZone()
	end
end

local function OnAddonLoaded(_, addonName)
	if addonName ~= UIT.name then return end
	EM:UnregisterForEvent(UIT.name, EVENT_ADD_ON_LOADED)
	UIT.Initialize()
end

EM:RegisterForEvent(UIT.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)