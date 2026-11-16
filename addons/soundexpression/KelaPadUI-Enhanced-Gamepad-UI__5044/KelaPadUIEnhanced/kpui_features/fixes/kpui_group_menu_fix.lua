-- KelaPadUI group menu fix.
--
-- The gamepad group menu keeps reacting to group events while it is closed.
-- See zo_groupmenu_gamepad.lua:
--   * InitializeEvents guards its handlers with
--     "if not self.control:IsControlHidden()".
--   * The group scene's fragment is GAMEPAD_GROUP_MENU_FRAGMENT, a
--     ZO_FadeSceneFragment on that control (ingamefragments_gamepad.lua).
--     ZO_AnimatedSceneFragment:Hide() only animates alpha and never calls
--     SetHidden(true), so IsControlHidden() is false for the whole session and
--     every guard passes.
--   * UpdateMenuList() then clears and refills the main list and reselects the
--     default row, index 2, which is MENU_ENTRY_TYPE_CURRENT_GROUP.
--   * OnSelectedMenuEntry acts on the current scene instead of the group
--     scene. It adds fragmentGroup = { the group list fragment,
--     GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT } through
--     SCENE_MANAGER:AddFragmentGroup, which attaches temporary fragments to
--     whichever scene is current, and a scene only drops those when that scene
--     reaches SCENE_HIDDEN. The empty member list and its background panel then
--     stay over the HUD until the UI reloads.
--   * It also calls GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP) and,
--     through GAMEPAD_GROUP_ROLES_BAR:Deactivate(), Reset on the same tooltip.
--     Both remove the tooltip fragment from the current scene, so the open
--     screen's help or item panel disappears until the player moves the
--     selection. Summoning or dismissing a pet is enough to trigger it.
--
-- Hiding the control is not enough on its own, because UpdateMenuList has no
-- guard of its own and other add-ons call it directly. LibGroupBroadcast's
-- LibGroupSocket, for example, calls GAMEPAD_GROUP_MENU:UpdateMenuList() from
-- its unit events (LibGroupSocket.lua:128), so dismissing a pet rebuilds the
-- closed menu and clears the open screen's left tooltip again.
--
-- The fix therefore does two things:
--   * It keeps the menu control hidden whenever the group scene is not
--     showing, so the game's own IsControlHidden guard works as intended.
--     The StateChange callback is registered with a priority so it runs before
--     the screen's own handler, because ZO_Scene:SetState fires callbacks
--     before it refreshes fragments.
--   * It pre-hooks UpdateMenuList, a pure UI rebuild, and skips it while the
--     group scene is hidden. Nothing is lost: OnStateChanged rebuilds the list
--     when the scene shows.
--
-- No secure or dialog function is hooked. The selection callback and the reset
-- are kept as a safety net for fragments that were already attached when the
-- scene hid.

local KELA_ADDON_NAME = "KelaPadUIEnhanced"

-- ZO_CallbackObject sorts prioritized callbacks ahead of unprioritized ones.
local KELA_GROUP_MENU_FIX_CALLBACK_PRIORITY = 1

local kelaGroupMenuFixBound = false

local function KelaGroupMenuFixIsGroupSceneShowing()
	return GAMEPAD_GROUP_SCENE ~= nil and GAMEPAD_GROUP_SCENE:IsShowing()
end

-- The menu is only visible while its scene is. Hiding the control makes the
-- game's own IsControlHidden guard work; ZO_AnimatedSceneFragment:Show()
-- unhides it again when the scene shows.
local function KelaGroupMenuFixSetMenuHidden(hidden)
	local menu = GAMEPAD_GROUP_MENU
	if menu and menu.control then
		menu.control:SetHidden(hidden)
	end
end

local function KelaGroupMenuFixRemoveFragmentGroup(scene, fragmentGroup)
	if scene and fragmentGroup and scene.RemoveTemporaryFragmentGroup then
		scene:RemoveTemporaryFragmentGroup(fragmentGroup)
	end
end

-- Returns the group menu to an inert state. Everything is guarded: the menu
-- finishes its deferred initialization on the first show, and the group list
-- and roles bar are separate gamepad panels.
function KelaGroupMenuFixReset()
	if KelaGroupMenuFixIsGroupSceneShowing() then
		return
	end

	local menu = GAMEPAD_GROUP_MENU
	local fragmentGroup = menu and menu.currentFragmentGroup
	if fragmentGroup then
		local currentScene = SCENE_MANAGER:GetCurrentScene()
		if currentScene ~= GAMEPAD_GROUP_SCENE then
			KelaGroupMenuFixRemoveFragmentGroup(currentScene, fragmentGroup)
		end
		KelaGroupMenuFixRemoveFragmentGroup(GAMEPAD_GROUP_SCENE, fragmentGroup)
		-- A leaked panel that reached the base scene survives there until the
		-- HUD hides, which is what makes it look permanent during play.
		KelaGroupMenuFixRemoveFragmentGroup(SCENE_MANAGER:GetBaseScene(), fragmentGroup)
		menu.currentFragmentGroup = nil
	end

	if GROUP_LIST_GAMEPAD and GROUP_LIST_GAMEPAD.Deactivate and GROUP_LIST_GAMEPAD.isActive then
		GROUP_LIST_GAMEPAD:Deactivate()
	end
	if GAMEPAD_GROUP_ROLES_BAR and GAMEPAD_GROUP_ROLES_BAR.Deactivate then
		GAMEPAD_GROUP_ROLES_BAR:Deactivate()
	end
	if GAMEPAD_GROUP_ROLES_FRAGMENT then
		local currentScene = SCENE_MANAGER:GetCurrentScene()
		if currentScene then
			currentScene:RemoveTemporaryFragment(GAMEPAD_GROUP_ROLES_FRAGMENT)
		end
	end
end

local function KelaGroupMenuFixOnSelectionChanged()
	if not KelaGroupMenuFixIsGroupSceneShowing() then
		KelaGroupMenuFixReset()
	end
end

-- UpdateMenuList is a pure UI rebuild: it clears and refills the menu list,
-- which reselects a row and fires the selection callback that clears the left
-- tooltip. Skipping it while the menu is closed is safe because the scene
-- rebuilds the list on its way in.
local function KelaGroupMenuFixBlockBackgroundRebuild()
	return not KelaGroupMenuFixIsGroupSceneShowing()
end

local function KelaGroupMenuFixOnSceneStateChanged(_, newState)
	if newState == SCENE_SHOWING then
		-- Visible before the screen's own handler rebuilds the list and
		-- refreshes its fragments.
		KelaGroupMenuFixSetMenuHidden(false)
	elseif newState == SCENE_HIDDEN then
		KelaGroupMenuFixSetMenuHidden(true)
		KelaGroupMenuFixReset()
	end
end

local function KelaGroupMenuFixBind()
	if kelaGroupMenuFixBound then
		return true
	end
	if not GAMEPAD_GROUP_SCENE or not GAMEPAD_GROUP_MENU or not GROUP_LIST_GAMEPAD then
		return false
	end
	if not GAMEPAD_GROUP_MENU.GetMainList then
		return false
	end

	local list = GAMEPAD_GROUP_MENU:GetMainList()
	if not list then
		return false
	end

	list:RegisterCallback("SelectedDataChanged", KelaGroupMenuFixOnSelectionChanged)
	GAMEPAD_GROUP_SCENE:RegisterCallback("StateChange", KelaGroupMenuFixOnSceneStateChanged, nil, KELA_GROUP_MENU_FIX_CALLBACK_PRIORITY)
	ZO_PreHook(GAMEPAD_GROUP_MENU, "UpdateMenuList", KelaGroupMenuFixBlockBackgroundRebuild)
	kelaGroupMenuFixBound = true

	-- Start inert. The scene is not showing at load, and the fade fragment only
	-- unhides the control on its way in.
	KelaGroupMenuFixSetMenuHidden(not KelaGroupMenuFixIsGroupSceneShowing())
	return true
end

local function KelaGroupMenuFixOnPlayerActivated()
	if KelaGroupMenuFixBind() then
		EVENT_MANAGER:UnregisterForEvent(KELA_ADDON_NAME, EVENT_PLAYER_ACTIVATED)
	end
end

function KelaSetupGroupMenuFix()
	if KelaGroupMenuFixBind() then
		return
	end

	EVENT_MANAGER:RegisterForEvent(KELA_ADDON_NAME, EVENT_PLAYER_ACTIVATED, KelaGroupMenuFixOnPlayerActivated)
end
