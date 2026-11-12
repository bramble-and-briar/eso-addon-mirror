-- KelaPadUI base-game gamepad UI fixes.
--
-- These mirror fixes that ZOS is preparing for a later game update and are
-- deliberately kept in their own module so they can be deleted in one step:
--   1. L2/R2 did not page battle round recaps on the Battleground scoreboard.
--      BATTLEGROUND_SCOREBOARD_PREVIOUS_ROUND / ..._NEXT_ROUND inherit from
--      DUMMY actions that have no default binding, and the scoreboard scenes
--      push their own action layer without the generic UI-shortcut layer. This
--      module adds that layer, shows the keybind strip on the end-of-game recap
--      (which keeps it hidden), and adds an ethereal L2/R2 keybind group while a
--      scoreboard scene shows so the press reaches the game's round paging
--      through the keybind strip without drawing a button.
--   2. The 6v6v6 and 9v9 scoreboards drew player rows taller than the panels
--      allocated for them, because the panel height assumed 32 px rows while
--      the score-label font list re-selected ZoFontGamepad34 (~40 px). Team
--      panels were therefore undersized and overlapped.
--   3. The Activity Finder kept the Battleground entry locked when its location
--      data arrived while the root screen was already open, because the gamepad
--      root never subscribes to the manager's "OnUpdateLocationData".
--
-- Remove this file and the KELA_SETTING_PANEL_FEATURES_BASE_GAME_FIXES setting
-- once the official fixes ship.

local KELA_ROW_HEIGHT_GAMEPAD = 40
local KELA_SMALL_ROW_HEIGHT_GAMEPAD = 32
local KELA_ROW_OFFSET_Y = 9

local KELA_BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD = -10
local KELA_BACKGROUND_DEFAULT_OFFSET_Y = -20
local KELA_BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD = -117
local KELA_BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD = -60

local KELA_SCORE_FONTS_NORMAL =
{
	{ font = "ZoFontGamepad34", lineLimit = 1 },
	{ font = "ZoFontGamepad27", lineLimit = 1 },
}
local KELA_SCORE_FONTS_SMALL =
{
	{ font = "ZoFontGamepad27", lineLimit = 1 },
}
local KELA_ROW_SCORE_LABEL_NAMES =
{
	"MedalScore",
	"Kills",
	"Deaths",
	"Assists",
	"Damage",
	"Heals",
	"GameTypeScore",
}

local kelaBaseGameFixesEnabled = false

-- Mirrors ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight as of
-- 12.2.0 (small rows use their own height instead of the large row height).
local function KelaGetPanelHeight(teamSize, useSmallPlayerEntries)
	local DEFAULT_TEAM_SIZE = 4
	if teamSize <= DEFAULT_TEAM_SIZE then
		return ZO_BATTLEGROUND_SCOREBOARD_PANEL_HEIGHT
	end

	local rowHeight = ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_KEYBOARD
	if IsInGamepadPreferredMode() then
		rowHeight = useSmallPlayerEntries and KELA_SMALL_ROW_HEIGHT_GAMEPAD or ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_GAMEPAD
	end

	return (teamSize * (rowHeight + ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y)) + ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_INITIAL_OFFSET_Y
end

-- Re-applies the container sizes from UpdateAll with the corrected panel
-- height. The background offsets mirror the file-local constants in
-- battlegroundscoreboard.lua.
local function KelaUpdateContainerHeights(fragment)
	if not fragment or not fragment:IsShowing() then
		return
	end
	if not fragment.currentBattlegroundId or fragment.currentBattlegroundId == 0 then
		return
	end

	local numBattlegroundTeams = GetBattlegroundNumTeams(fragment.currentBattlegroundId)
	local teamSize = GetBattlegroundTeamSize(fragment.currentBattlegroundId)
	local hasRounds = DoesBattlegroundHaveRounds(fragment.currentBattlegroundId)

	local teamPanelHeight = KelaGetPanelHeight(teamSize, fragment:ShouldScoreboardUseSmallPlayerEntries())
	local totalTeamPanelsHeight = teamPanelHeight * numBattlegroundTeams + ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y * (numBattlegroundTeams - 1)
	totalTeamPanelsHeight = totalTeamPanelsHeight + 5

	local maxContainerHeight = hasRounds and ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT_WITH_ROUNDS or ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT
	local containerHeight = zo_min(totalTeamPanelsHeight, maxContainerHeight)
	fragment.panelContainer:SetHeight(containerHeight)

	local backgroundsHeight = containerHeight + ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEIGHT + ZO_BATTLEGROUND_SCOREBOARD_PADDING_HEIGHT * 2
	fragment.backgroundsContainer:SetHeight(backgroundsHeight)
	fragment.backgroundsContainer:ClearAnchors()

	local backgroundsContainerOffsetY = KELA_BACKGROUND_DEFAULT_OFFSET_Y
	if hasRounds and containerHeight >= maxContainerHeight then
		if IsInGamepadPreferredMode() then
			backgroundsContainerOffsetY = KELA_BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD
		else
			backgroundsContainerOffsetY = KELA_BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD
		end
	end

	local backgroundsContainerOffsetX = 0
	if IsInGamepadPreferredMode() then
		backgroundsContainerOffsetX = KELA_BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD
	end

	fragment.backgroundsContainer:SetAnchor(CENTER, nil, CENTER, backgroundsContainerOffsetX, backgroundsContainerOffsetY)
end

-- Small rows keep the single 27 px font so they stay at the 32 px row height
-- the panel height expects. Normal rows restore the game's 34 -> 27 list.
local function KelaApplyScoreLabelFonts(label, useSmallPlayerEntries)
	if not label or not label.MarkDirty then
		return
	end

	label.fonts = useSmallPlayerEntries and KELA_SCORE_FONTS_SMALL or KELA_SCORE_FONTS_NORMAL
	label.maxLines = 1
	label.dontUseMaxLinesForAdjusting = nil
	label:SetMaxLineCount(1)
	label.forceUpdate = true
	label:MarkDirty()
end

local function KelaApplyRowFonts(row)
	if not row or not row.control then
		return
	end

	-- The keyboard scoreboard keeps the core font list untouched.
	if not IsInGamepadPreferredMode() then
		return
	end

	local panel = row.panel
	if not panel then
		return
	end

	local useSmallPlayerEntries = panel:ShouldUseSmallPlayerEntries()
	for i = 1, #KELA_ROW_SCORE_LABEL_NAMES do
		KelaApplyScoreLabelFonts(row.control:GetNamedChild(KELA_ROW_SCORE_LABEL_NAMES[i]), useSmallPlayerEntries)
	end
end

-- Called from the scoreboard keybind group below. Returns true when the
-- scoreboard consumed the press.
function KelaBattlegroundMoveViewedRound(delta)
	if not kelaBaseGameFixesEnabled or not IsInGamepadPreferredMode() then
		return false
	end

	local fragment = BATTLEGROUND_SCOREBOARD_FRAGMENT
	if fragment and fragment:IsShowing() and fragment.roundSummary and fragment.roundSummary:IsVisible() then
		local keybind = delta < 0 and "BATTLEGROUND_SCOREBOARD_PREVIOUS_ROUND" or "BATTLEGROUND_SCOREBOARD_NEXT_ROUND"
		fragment:OnKeybindDown(keybind)
		return true
	end

	return false
end

-- The scoreboard scenes only push their own action layer (BattlegroundScoreboard),
-- so the generic UI-shortcut actions that forward L2/R2 to the keybind strip
-- never run there. Add the shortcut layer to the scene; the scoreboard's own
-- actions are not defined in that layer, so its buttons keep their priority and
-- anything the strip does not handle still falls through. This only changes the
-- layer stack at setup time; nothing wraps the input dispatchers.
local function KelaAddUIShortcutsLayer(scene)
	if not scene or not UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then
		return
	end

	scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT)
end

-- The scoreboard never binds L2/R2, so paging used to be forwarded by a secure
-- post-hook on ZO_KeybindStrip_HandleKeybindDown. That hook ran the dispatcher's
-- original body inside the engine's PostHookFunction trampoline, which taints
-- the callstack for every press that reaches the keybind strip. Dialog buttons
-- that fall through to the strip then failed on private calls: accepting a duel
-- or a ready check raised "Attempt to access a private function
-- 'CancelTaskbarWindowFlash' from insecure code". The bindings are ethereal
-- group entries on the scoreboard scenes instead: they are dispatched like any
-- other keybind but draw no button, so nothing sits on the input path and the
-- recap screen looks unchanged.
local KELA_SCOREBOARD_KEYBINDS =
{
	alignment = KEYBIND_STRIP_ALIGN_CENTER,
	{
		keybind = "UI_SHORTCUT_LEFT_TRIGGER",
		ethereal = true,
		callback = function() KelaBattlegroundMoveViewedRound(-1) end,
	},
	{
		keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
		ethereal = true,
		callback = function() KelaBattlegroundMoveViewedRound(1) end,
	},
}

-- The end-of-game recap is a separate scene from the in-game scoreboard, and
-- one can hide while the other shows during the transition, so the group is
-- reference counted instead of toggled per scene.
local kelaScoreboardScenesShowing = 0

local function KelaShowScoreboardKeybinds()
	kelaScoreboardScenesShowing = kelaScoreboardScenesShowing + 1
	if kelaScoreboardScenesShowing == 1 then
		KEYBIND_STRIP:AddKeybindButtonGroup(KELA_SCOREBOARD_KEYBINDS)
	end
end

local function KelaHideScoreboardKeybinds()
	if kelaScoreboardScenesShowing > 0 then
		kelaScoreboardScenesShowing = kelaScoreboardScenesShowing - 1
	end
	if kelaScoreboardScenesShowing == 0 then
		KEYBIND_STRIP:RemoveKeybindButtonGroup(KELA_SCOREBOARD_KEYBINDS)
	end
end

-- The in-game scoreboard adds the gamepad keybind strip group itself, so the
-- strip control is visible there and the ethereal group above is dispatched.
-- The end-of-game recap draws its own keybind buttons and never adds the strip,
-- leaving the control hidden, so the group would never receive a press. Showing
-- only the strip fragment (not the backdrop group) keeps the recap looking the
-- same: the group draws no button, so the strip stays empty and see-through.
local function KelaRefreshScoreboardKeybindStrip(scene)
	if not scene or not KEYBIND_STRIP_GAMEPAD_FRAGMENT then
		return
	end

	if IsInGamepadPreferredMode() then
		scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
	else
		scene:RemoveFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
	end
end

local function KelaRegisterScoreboardKeybinds(scene, showKeybindStrip)
	if not scene or scene.kelaScoreboardKeybindsRegistered then
		return
	end

	scene.kelaScoreboardKeybindsRegistered = true
	KelaAddUIShortcutsLayer(scene)
	scene:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWING then
			if showKeybindStrip then
				KelaRefreshScoreboardKeybindStrip(scene)
			end
			KelaShowScoreboardKeybinds()
		elseif newState == SCENE_HIDDEN then
			KelaHideScoreboardKeybinds()
		end
	end)
end

local function KelaRefreshActivityFinderCategories()
	local root = ZO_ACTIVITY_FINDER_ROOT_GAMEPAD
	if not root or not root.scene or not root.scene:IsShowing() then
		return
	end

	local list = root:GetMainList()
	if not list then
		return
	end

	-- Commit rebuilds the rows so CategoryEntrySetup recomputes the cached lock
	-- state from the fresh location data; RefreshList restores the fragment,
	-- tooltip, and keybind strip the same way OnShowing does.
	list:Commit()
	root:RefreshList()
end

function KelaSetupBaseGameFixes()
	kelaBaseGameFixesEnabled = true

	KelaRegisterScoreboardKeybinds(BATTLEGROUND_SCOREBOARD_END_OF_GAME_SCENE, true)
	KelaRegisterScoreboardKeybinds(BATTLEGROUND_SCOREBOARD_IN_GAME_SCENE, false)

	-- The official fix defines this constant. Skip the layout patch when it is
	-- already present so both fixes never stack.
	if ZO_BATTLEGROUND_SCOREBOARD_PLAYER_SMALL_ROW_HEIGHT_GAMEPAD == nil then
		ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_GAMEPAD = KELA_ROW_HEIGHT_GAMEPAD
		ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y = KELA_ROW_OFFSET_Y

		SecurePostHook(ZO_Battleground_Scoreboard_Team_Panel_Object, "UpdatePanelHeight", function(panel)
			panel.control:SetHeight(KelaGetPanelHeight(panel.teamSize, panel:ShouldUseSmallPlayerEntries()))
		end)

		-- Core sets the team size before the small-entry flag, so the height has
		-- to be recalculated once the flag changes.
		SecurePostHook(ZO_Battleground_Scoreboard_Team_Panel_Object, "UseSmallPlayerEntries", function(panel)
			panel:UpdatePanelHeight()
		end)

		SecurePostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(fragment)
			KelaUpdateContainerHeights(fragment)
		end)

		SecurePostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "SetupOnAcquire", function(row)
			KelaApplyRowFonts(row)
		end)
	end

	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", KelaRefreshActivityFinderCategories)
end
