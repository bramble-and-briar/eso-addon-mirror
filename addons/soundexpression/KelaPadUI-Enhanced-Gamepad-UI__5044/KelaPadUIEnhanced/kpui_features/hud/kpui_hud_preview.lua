-- Shows the ability bar and attribute bars behind the KelaPadUI settings, so
-- the Ability Bar options (raise, timer style, attribute bar shift) can be seen
-- while they are changed. Both use the game's own public show requests:
--   * ZO_ContextualActionBar_AddReference: the ability bar shows as if it were
--     in use. The game's "Never" choice for the ability bar still wins.
--   * PLAYER_ATTRIBUTE_BARS:ForceShow: the attribute bars stop fading out.
-- Each request is released when the settings close.

local OPTIONS_SCENE_NAME = "kela_options_root"

function KelaSetupHudPreview()
	if KelaPadUI.KelaHudPreviewInitialized then
		return
	end
	KelaPadUI.KelaHudPreviewInitialized = true

	local scene = SCENE_MANAGER:GetScene(OPTIONS_SCENE_NAME)
	if not scene or not ACTION_BAR_FRAGMENT or not PLAYER_ATTRIBUTE_BARS_FRAGMENT or not PLAYER_ATTRIBUTE_BARS then
		return
	end
	scene:AddFragment(ACTION_BAR_FRAGMENT)
	scene:AddFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)

	-- Keeps the add and remove calls paired, whatever order the states arrive in.
	local previewing = false
	scene:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWING and not previewing then
			previewing = true
			ZO_ContextualActionBar_AddReference()
			PLAYER_ATTRIBUTE_BARS:ForceShow(true)
		elseif newState == SCENE_HIDDEN and previewing then
			previewing = false
			ZO_ContextualActionBar_RemoveReference()
			PLAYER_ATTRIBUTE_BARS:ForceShow(false)
		end
	end)
end
