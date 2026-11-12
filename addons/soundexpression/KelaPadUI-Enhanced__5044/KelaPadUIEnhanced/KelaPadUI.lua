KelaPadUI = {
	name = "KelaPadUIEnhanced",
	displayName = "|cFF00FF" .. "KelaPadUI Enhanced interface for Gamepad UI" .. "|r",
}

-- Optional diagnostics channel.  LibDebugLogger writes to the saved variables
-- file, which is the only way to read add-on output on a gamepad UI where chat
-- text cannot be copied out.  Nil when the library is not installed.
KelaPadUI.log = LibDebugLogger and LibDebugLogger:Create(KelaPadUI.name)

-- The abandoned original add-on installs as the folder "KelaPadUI" and shares
-- both the KelaPadUI global and the kpuiSavedVariables file. Running the two
-- together corrupts settings, so this build stays inert while it is present.
local KELA_LEGACY_ADDON_NAME = "KelaPadUI"

local _initialized = false

local function KelaLegacyAddonLoaded()
	local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
	if not isLoaded then return false end
	local ok, loaded = pcall(isLoaded, KELA_LEGACY_ADDON_NAME)
	return ok and loaded == true
end

local function KelaShowLegacyConflictDialog()
	ZO_Dialogs_RegisterCustomDialog("KELA_LEGACY_ADDON_CONFLICT",
	{
		gamepadInfo =
		{
			dialogType = GAMEPAD_DIALOGS.BASIC,
		},
		title =
		{
			text = KELA_LEGACY_CONFLICT_TITLE,
		},
		mainText =
		{
			text = KELA_LEGACY_CONFLICT_MESSAGE,
		},
		buttons =
		{
			[1] =
			{
				text = SI_DIALOG_EXIT,
			},
		},
	})
	pcall(ZO_Dialogs_ShowGamepadDialog, "KELA_LEGACY_ADDON_CONFLICT")
end

local function KelaWarnLegacyAddon()
	KelaPadUI.legacyConflict = true
	if KelaPadUI.log then
		KelaPadUI.log:Error(
			"The original KelaPadUI add-on is still installed, so KelaPadUI Enhanced did not start. "
			.. "Delete the KelaPadUI, KelaPadUIBuyingData and KelaPadUIListingData folders, then reload the UI."
		)
	end
	-- Dialogs are unreliable before the gamepad UI exists, so show the notice
	-- once the player is in game.
	EVENT_MANAGER:RegisterForEvent(KelaPadUI.name, EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(KelaPadUI.name, EVENT_PLAYER_ACTIVATED)
		zo_callLater(KelaShowLegacyConflictDialog, 2000)
	end)
end

--KelaPadUI scenes
local kelaSetsScene = SCENE_MANAGER:GetScene("kelaSets")
GAMEPAD_SETS_LIST_FRAGMENT = ZO_FadeSceneFragment:New(Kela_Sets_List_Gamepad)
kelaSetsScene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
kelaSetsScene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_RIGHT)
kelaSetsScene:AddFragment(GAMEPAD_SETS_LIST_FRAGMENT)
kelaSetsScene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
kelaSetsScene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT)
kelaSetsScene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
kelaSetsScene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
GAMEPAD_TOOLTIPS:AddTooltipInstantScene(GAMEPAD_RIGHT_TOOLTIP, kelaSetsScene)

-----------------------
--Options Root Scene
-----------------------
KELA_OPTIONS_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
KELA_OPTIONS_ROOT_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
KELA_OPTIONS_ROOT_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
KELA_OPTIONS_ROOT_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
KELA_OPTIONS_ROOT_SCENE:AddFragment(MINIMIZE_CHAT_FRAGMENT)
KELA_OPTIONS_ROOT_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
KELA_OPTIONS_ROOT_SCENE:AddFragment(KELA_OPTIONS_FRAGMENT)
KELA_OPTIONS_ROOT_SCENE:AddFragment(KELA_OPTIONS:GetHeaderFragment())

function KelaSetupTooltips()
	local tooltipLeft = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
	local tooltipRight = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)	
	local tooltipQuad1 = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_QUAD1_TOOLTIP)	

	kelaTotalRedefineStyles()

	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:ClearAnchors()
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 535, 53) 
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 535, -125) 
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetWidth(KELA_TOOLTIPS_WIDTH)

	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control:ClearAnchors()
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -10, 53) 
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -10, -125) 
	GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control:SetWidth(KELA_TOOLTIPS_WIDTH)
	
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_RIGHT_TOOLTIP.control:ClearAnchors()
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_RIGHT_TOOLTIP.control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -10, 53) 
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_RIGHT_TOOLTIP.control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -10, -125) 		
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_RIGHT_TOOLTIP.control:SetWidth(KELA_TOOLTIPS_WIDTH)		
	
	LOOT_WINDOW_GAMEPAD.control:ClearAnchors()
	LOOT_WINDOW_GAMEPAD.control:SetAnchor(TOPRIGHT, GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control, TOPLEFT, -5, 0) 
	LOOT_WINDOW_GAMEPAD.control:SetAnchor(BOTTOMRIGHT, GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_RIGHT_TOOLTIP.control, BOTTOMLEFT, -5, 0) 
	LOOT_WINDOW_GAMEPAD.control:SetWidth(520)		
	


	kelaReplaceTooltips (tooltipLeft)
	kelaReplaceTooltips (tooltipRight)
	kelaReplaceTooltipQuad1 (tooltipQuad1)


	-- Core builds this table before add-ons change ZO_TOOLTIP_STYLES, so rebuild it
	-- here for the core crafting tooltip consumer.
	ZO_CRAFTING_TOOLTIP_STYLES = ZO_DeepTableCopy(ZO_TOOLTIP_STYLES)
	for key,value in pairs(ZO_CRAFTING_TOOLTIP_STYLES) do
		value["horizontalAlignment"] = TEXT_ALIGN_CENTER

		if key ~= "topSection" then
			value["layoutPrimaryDirectionCentered"] = true
		end
	end

end



local function KelaPadUI_OnLoaded(eventType, addonName)
	if _initialized then return end
	if addonName ~= KelaPadUI.name then return end
	EVENT_MANAGER:UnregisterForEvent(KelaPadUI.name, EVENT_ADD_ON_LOADED)

	-- "KelaPadUI" sorts before "KelaPadUIEnhanced", so the original add-on has
	-- already registered its own load handler by the time this one runs.
	if KelaLegacyAddonLoaded() then
		KelaWarnLegacyAddon()
		_initialized = true
		return
	end

	KelaInitializeSettings()

	KelaSetupMainMenuHeader()

	local function IsFeatureEnabled(settingId)
		return KelaGetSetting_Bool(SETTING_TYPE_KELA, settingId)
	end

	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS) then
		KelaSetupAntiquityLeadInfo()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_TRAIT_RESEARCH_ENABLED) then
		KelaSetupTraitResearch()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS) then
		KelaSetupAntiquityFilters()
		KelaSetupMenuFilters()
		KelaSetupRecipeFilters()
		KelaSetupAchievementFilters()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES) then
		KelaSetupBaseGameFixes()
	end

	KELA_SETS_LIST:SetMasterSetsList()

	local hasTradingProvider = TamrielTradeCentre ~= nil or ArkadiusTradeTools ~= nil
	if hasTradingProvider and IsFeatureEnabled(KELA_SETTING_PANEL_TRADE_ENABLED) then
		KelaInitializeTradingHistory()
		KelaSetupTradingHouse()
		KelaSetupCraftingStation()
	elseif not hasTradingProvider then
		KelaSetSetting(SETTING_TYPE_KELA, KELA_SETTING_PANEL_TRADE_ENABLED, false)
	end

	-- Extra functions added
	KelaSetupTooltips()
	KelaSetupPS5ButtonMap()
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_COMPANION) then
		KelaSetupCompanionInfo()
		KelaSetupCompanionCollections()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER) then
		KelaSetupDungeonFinder()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS) then
		KelaSetupChatTools()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_MAP_RALLY) then
		KelaSetupMapRally()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS) then
		KelaSetupMainMenuShortcuts()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD) then
		KelaSetupMainMenuDashboard()
	end
	if IsFeatureEnabled(KELA_SETTING_PANEL_FEATURES_PA_JUNK) then
		KelaSetupPAJunk()
	end

	_initialized = true

end

EVENT_MANAGER:RegisterForEvent(KelaPadUI.name, EVENT_ADD_ON_LOADED, KelaPadUI_OnLoaded)
