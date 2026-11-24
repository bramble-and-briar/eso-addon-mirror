SchrodisBattlegroundTools = {}
local sbt = SchrodisBattlegroundTools
sbt.name = "SchrodisBattlegroundTools"
sbt.title = "Schrodi's Battleground Tools"
sbt.version = "2.0.1"
sbt.queues = {}
sbt.rows = {}
sbt.vars = {}

-- "Auto requeue": deliberately not saved, off after every /reloadui or relog.
sbt.requeueAutomatically = false

local SBT_DEFAULTS = {
	selectedQueues = {},
}

-- Account-wide preferences. Colors are 0-1 RGBA tables (LibAddonMenu's colorpicker format).
local defaultAccountSettings = {
	lastSelectedBattlegroundMode = nil,
	saveVanillaBattlegroundMode = true,
	nameDisplayMode = "default",
	showQuickQueueButtons = true,
	replaceBattlegroundsPanel = true,
	queueTimerInTracker = true,
	competitiveColor = { r = 0xC5 / 255, g = 0x96 / 255, b = 0x15 / 255, a = 1 },
	standardColor = { r = 0x00 / 255, g = 0xAA / 255, b = 0x00 / 255, a = 1 },
	healColor = { r = 1, g = 0.85, b = 0, a = 1 },
	damageColor = { r = 1, g = 1, b = 1, a = 1 },
}

-------------------------------------------------------------------------------------------------
--  Scoreboard layout: drop the base game's own Damage/Heals/game-type columns, fit big lobbies  --
-------------------------------------------------------------------------------------------------
-- Since 12.1.5 the base game has its own Damage, Heals and a game-type score column (flags
-- captured / flag carry time / damage taken, shown under a battlegrounds icon) at the right end of
-- every row. Damage/heal are already shown by this addon right next to Score, so all three are
-- hidden (header + row cells) and the window is narrowed back to its pre-12.1.5 width.
--
-- Height: the base game caps the team list at ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT
-- (3 x 4-player panels), which is too short for 9v9 or 6v6v6 (18 rows at 40px each) and leaves a
-- scrollbar. Instead the cap follows the screen height (never below the base cap), and if the
-- lobby still doesn't fit with the normal row spacing, the gap between rows (and the panel's top
-- padding) shrinks just enough for everyone to fit.

-- Base 12.1.5 widened the header by 150 for its 3 new columns, and each row by 3 x (column + pad).
local SBT_REMOVED_WINDOW_WIDTH = 150
local SBT_REMOVED_ROW_WIDTH = ZO_BATTLEGROUND_SCOREBOARD_HEADER_DAMAGE_WIDTH + ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEALS_WIDTH + ZO_BATTLEGROUND_SCOREBOARD_HEADER_GAME_TYPE_WIDTH + 3 * ZO_BATTLEGROUND_SCOREBOARD_HEADER_DOUBLE_PADDING
local SBT_REMOVED_COLUMN_NAMES = { "Damage", "Heals", "GameTypeScore" }

-- Room left for everything around the team list (header 90 + padding 60, the keyboard background's
-- decorative overhang 186, keybind strip): with this, a 1080-high GuiRoot gives exactly the base
-- game's own cap (680), and only taller UIs get a taller window.
local SBT_SCOREBOARD_SCREEN_RESERVE = 400
local SBT_ROUNDS_RESERVE = ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT - ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT_WITH_ROUNDS
local SBT_DEFAULT_TEAM_SIZE = 4 -- base GetPanelHeight uses a fixed 220px panel up to this size
local SBT_MIN_ROW_GAP = 2
local SBT_MIN_INITIAL_OFFSET = 8
local SBT_LIST_PADDING = 5 -- base adds this so the list isn't right against the scroll limits

-- nil = base layout (normal spacing). Otherwise { gap = px between rows, initialOffset = px above
-- the first row }. Recomputed at the start of every scoreboard UpdateAll.
sbt.rowLayout = nil

local function sbt_getRowHeight()
	if IsInGamepadPreferredMode() then
		return ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_GAMEPAD
	end
	return ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_KEYBOARD
end

local function sbt_getMaxContainerHeight(hasRounds)
	local baseMax = hasRounds and ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT_WITH_ROUNDS or ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT
	local screenMax = GuiRoot:GetHeight() - SBT_SCOREBOARD_SCREEN_RESERVE - (hasRounds and SBT_ROUNDS_RESERVE or 0)
	return zo_max(baseMax, screenMax)
end

local function sbt_getTotalPanelsHeight(numTeams, panelHeight)
	return panelHeight * numTeams + ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y * (numTeams - 1) + SBT_LIST_PADDING
end

local function sbt_computeRowLayout(fragment)
	sbt.rowLayout = nil

	local battlegroundId = fragment.currentBattlegroundId
	if not battlegroundId or battlegroundId == 0 then return end

	local teamSize = GetBattlegroundTeamSize(battlegroundId)
	local numTeams = GetBattlegroundNumTeams(battlegroundId)
	if teamSize <= SBT_DEFAULT_TEAM_SIZE or numTeams < 1 then return end

	local maxHeight = sbt_getMaxContainerHeight(DoesBattlegroundHaveRounds(battlegroundId))
	local rowHeight = sbt_getRowHeight()
	local gap = ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y
	local initialOffset = ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_INITIAL_OFFSET_Y

	local function fits(rowGap, offset)
		return sbt_getTotalPanelsHeight(numTeams, teamSize * (rowHeight + rowGap) + offset) <= maxHeight
	end
	if fits(gap, initialOffset) then return end -- base spacing already fits, nothing to change

	local function largestGap(offset)
		local available = maxHeight - SBT_LIST_PADDING - ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y * (numTeams - 1) - numTeams * offset
		return zo_floor(available / (numTeams * teamSize)) - rowHeight
	end

	local newGap = largestGap(initialOffset)
	if newGap < SBT_MIN_ROW_GAP then
		initialOffset = SBT_MIN_INITIAL_OFFSET
		newGap = largestGap(initialOffset)
	end
	-- Still too tall even with no gap at all: keep it at 0 and let the base scrollbar handle the rest.
	sbt.rowLayout = { gap = zo_clamp(newGap, 0, gap), initialOffset = initialOffset }
end

local function sbt_isCompactRowLayout()
	return sbt.rowLayout ~= nil and sbt.rowLayout.gap < ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y
end

-- Team panel height / row anchoring with sbt.rowLayout applied. GetPanelHeight is a plain function
-- (called as ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight(teamSize) and as
-- self.GetPanelHeight(teamSize)), so it's replaced on the class rather than hooked.
local baseGetPanelHeight = ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight
ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight = function(teamSize)
	local layout = sbt.rowLayout
	if not layout or teamSize <= SBT_DEFAULT_TEAM_SIZE then
		return baseGetPanelHeight(teamSize)
	end
	return teamSize * (sbt_getRowHeight() + layout.gap) + layout.initialOffset
end

local baseTeamPanelUpdateAnchors = ZO_Battleground_Scoreboard_Team_Panel_Object.UpdateAnchors
function ZO_Battleground_Scoreboard_Team_Panel_Object:UpdateAnchors()
	local layout = sbt.rowLayout
	if not layout or self.teamSize <= SBT_DEFAULT_TEAM_SIZE then
		return baseTeamPanelUpdateAnchors(self)
	end

	local previousControl
	for _, playerRow in ipairs(self.sortedPlayerRows) do
		local control = playerRow.control
		control:ClearAnchors()
		if previousControl then
			control:SetAnchor(TOPLEFT, previousControl, BOTTOMLEFT, 0, layout.gap)
		else
			control:SetAnchor(TOPLEFT, self.control, TOPLEFT, self.initialPlayerRowOffsetX, layout.initialOffset)
		end
		previousControl = control
	end
end

-- Narrower window (no Damage/Heals/game-type columns). Re-applied after every UpdateAll, which the
-- base game also runs at the end of every platform-style (keyboard/gamepad) switch, so templates
-- re-applied there can't undo it.
local function sbt_applyScoreboardWidth(fragment)
	local headers = fragment.headers
	headers:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_HEADER_WIDTH - SBT_REMOVED_WINDOW_WIDTH)
	local divider = headers:GetNamedChild("Divider")
	if divider and ZO_BATTLEGROUND_SCOREBOARD_HEADER_DIVIDER_WIDTH then
		divider:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_HEADER_DIVIDER_WIDTH - SBT_REMOVED_WINDOW_WIDTH)
	end
	for _, columnName in ipairs(SBT_REMOVED_COLUMN_NAMES) do
		local header = headers:GetNamedChild(columnName)
		if header then header:SetHidden(true) end
	end

	fragment.backgroundsContainer:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_BACKGROUND_WIDTH - SBT_REMOVED_WINDOW_WIDTH)
	fragment.keyboardBackground:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_BACKGROUND_WIDTH_KEYBOARD - SBT_REMOVED_WINDOW_WIDTH)
	fragment.panelContainer:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_WIDTH - SBT_REMOVED_WINDOW_WIDTH)

	local teamBgWidth = IsInGamepadPreferredMode() and ZO_BATTLEGROUND_SCOREBOARD_TEAM_WIDTH_GAMEPAD or ZO_BATTLEGROUND_SCOREBOARD_TEAM_WIDTH_KEYBOARD
	for _, teamPanel in pairs(fragment.teamPanels) do
		teamPanel.control:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PANEL_WIDTH - SBT_REMOVED_WINDOW_WIDTH)
		teamPanel.bgControl:SetWidth(teamBgWidth - SBT_REMOVED_WINDOW_WIDTH)
	end
end

-- Mirrors the container/background sizing at the top of the base UpdateAll, but with
-- sbt_getMaxContainerHeight instead of the base fixed cap (the panel heights themselves already
-- come from the replaced GetPanelHeight above).
local BACKGROUND_DEFAULT_OFFSET_X = 0
local BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD = -10
local BACKGROUND_DEFAULT_OFFSET_Y = -20
local BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD = -60
local BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD = -117

local function sbt_applyScoreboardHeight(fragment)
	local battlegroundId = fragment.currentBattlegroundId
	if not battlegroundId or battlegroundId == 0 then return end

	local hasRounds = DoesBattlegroundHaveRounds(battlegroundId)
	local numTeams = GetBattlegroundNumTeams(battlegroundId)
	local teamSize = GetBattlegroundTeamSize(battlegroundId)
	local totalHeight = sbt_getTotalPanelsHeight(numTeams, ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight(teamSize))
	local maxHeight = sbt_getMaxContainerHeight(hasRounds)
	-- Within the base's own 5px padding of the cap: show it all rather than scroll 5px (4v4v4).
	local containerHeight = (totalHeight <= maxHeight + SBT_LIST_PADDING) and totalHeight or maxHeight
	fragment.panelContainer:SetHeight(containerHeight)

	fragment.backgroundsContainer:SetHeight(containerHeight + ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEIGHT + ZO_BATTLEGROUND_SCOREBOARD_PADDING_HEIGHT * 2)
	fragment.backgroundsContainer:ClearAnchors()
	local isGamepad = IsInGamepadPreferredMode()
	local offsetY = BACKGROUND_DEFAULT_OFFSET_Y
	if hasRounds and containerHeight >= maxHeight then
		offsetY = isGamepad and BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD or BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD
	end
	local offsetX = isGamepad and BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD or BACKGROUND_DEFAULT_OFFSET_X
	fragment.backgroundsContainer:SetAnchor(CENTER, nil, CENTER, offsetX, offsetY)
end

ZO_PreHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(self)
	sbt_computeRowLayout(self)
end)

-------------------------------------------------------------------------------------------------
--  Scoreboard rows: class icon, damage and healing, one name  --
-------------------------------------------------------------------------------------------------
-- Every player row gets a class icon left of the name and, right of the medal score, damage done
-- (top) and healing done (bottom). The controls are created once per row control (the game pools
-- them) and refreshed whenever the game refreshes the row itself: the scoreboard redraws every
-- row after each update, and each row knows its own scoreboard entry, so nothing has to be
-- matched up by name.

-- Which name the row shows ("Player name display" setting).
local SBT_NAME_FORMATS = {
	default = function(characterName, displayName) return ZO_ShouldPreferUserId() and displayName or characterName end,
	userid = function(characterName, displayName) return displayName end,
	charname = function(characterName, displayName) return characterName end,
	userid_charname = function(characterName, displayName) return zo_strformat("<<1>> (<<2>>)", displayName, characterName) end,
	charname_userid = function(characterName, displayName) return zo_strformat("<<1>> (<<2>>)", characterName, displayName) end,
}

local function sbt_formatPlayerName(data)
	local format = SBT_NAME_FORMATS[sbt.accountVars.nameDisplayMode] or SBT_NAME_FORMATS.default
	return format(zo_strformat(SI_PLAYER_NAME, data.characterName), zo_strformat(SI_PLAYER_NAME, data.displayName))
end

-- 12345 -> "12k": the column is narrow, thousands are precise enough to compare players.
local function sbt_formatThousands(value)
	return zo_floor((value or 0) / 1000) .. "k"
end

-- Damage and healing for the round the scoreboard is showing, or the whole match when it shows
-- the totals (same choice the game makes for its own score columns).
local function sbt_getDamageAndHealing(entryIndex)
	local scoreboard = BATTLEGROUND_SCOREBOARD_FRAGMENT
	local getScore, roundIndex
	if scoreboard:ShouldShowAggregateScores() then
		getScore, roundIndex = GetBattlegroundCumulativeScoreForScoreboardEntryByType, GetCurrentBattlegroundRoundIndex()
	else
		getScore, roundIndex = GetScoreboardEntryScoreByType, scoreboard.viewedRound
	end
	return getScore(entryIndex, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex), getScore(entryIndex, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex)
end

-- Damage/healing sit as a pair next to the medal score; compact rows (big lobbies, see
-- sbt.rowLayout) get a smaller font and a tighter pair so they don't run into the next row.
-- Both labels stay anchored at the row's vertical center and are only shifted when drawn
-- (transform offset): an anchor offset would push them past the row's edges, and the row grows
-- to fit its children -- every row taller, a full lobby with a scrollbar.
local SBT_STATS_OFFSET_X = 15
local SBT_STATS_NORMAL = { font = "ZoFontGame", damageY = -5, healY = 15 }
local SBT_STATS_COMPACT = { font = "ZoFontGameSmall", damageY = -8, healY = 8 }

local function sbt_layoutStats(stats)
	local style = sbt_isCompactRowLayout() and SBT_STATS_COMPACT or SBT_STATS_NORMAL
	if stats.style == style then return end
	stats.style = style
	for key, offsetY in pairs({ damage = style.damageY, heal = style.healY }) do
		stats[key]:SetFont(style.font)
		stats[key]:SetTransformOffsetY(offsetY)
	end
end

local function sbt_setColor(control, color)
	control:SetColor(color.r, color.g, color.b, color.a)
end

local SBT_HIDDEN_BASE_CELLS = { "damageLabel", "healsLabel", "gameTypeScoreLabel" }

local function sbt_refreshRow(rowObject)
	local stats = rowObject.sbtStats
	if not stats then return end

	-- The game shows its own Damage/Heals/game-type cells again on every refresh.
	for _, key in ipairs(SBT_HIDDEN_BASE_CELLS) do
		local cell = rowObject[key]
		if cell then cell:SetHidden(true) end
	end

	sbt_layoutStats(stats)

	local data = rowObject.data
	if not data or data.isPlaceholderEntry then -- empty slot in a battleground that isn't full yet
		rowObject.nameLabel:SetText("")
		stats.classIcon:SetHidden(true)
		stats.damage:SetText("")
		stats.heal:SetText("")
		return
	end

	rowObject.nameLabel:SetText(sbt_formatPlayerName(data))

	local classIcon = ZO_GetGamepadClassIcon(GetScoreboardEntryClassId(data.entryIndex))
	stats.classIcon:SetTexture(classIcon or "")
	stats.classIcon:SetHidden(classIcon == nil)

	local damage, healing = sbt_getDamageAndHealing(data.entryIndex)
	stats.damage:SetText(sbt_formatThousands(damage))
	stats.heal:SetText(sbt_formatThousands(healing))
	-- Colors come from the settings, so they're set on every refresh to follow changes live.
	sbt_setColor(stats.damage, sbt.accountVars.damageColor)
	sbt_setColor(stats.heal, sbt.accountVars.healColor)
end

local SBT_CLASS_ICON_SIZE = 24

local function sbt_addRowControls(rowObject, control)
	-- The row's own height before anything is added: the extra controls are taller than a row and
	-- would otherwise make every row (and a full lobby) taller.
	local rowHeight = control:GetHeight()
	local name = control:GetName()

	local stats = {}
	stats.damage = CreateControl(name .. "SbtDamage", control, CT_LABEL)
	stats.heal = CreateControl(name .. "SbtHealing", control, CT_LABEL)
	for _, label in ipairs({ stats.damage, stats.heal }) do
		label:SetAnchor(LEFT, rowObject.medalScoreLabel, RIGHT, SBT_STATS_OFFSET_X, 0)
	end
	stats.classIcon = CreateControl(name .. "SbtClass", control, CT_TEXTURE)
	stats.classIcon:SetDimensions(SBT_CLASS_ICON_SIZE, SBT_CLASS_ICON_SIZE)
	stats.classIcon:SetAnchor(RIGHT, rowObject.nameLabel, LEFT, -2, 0)
	stats.classIcon:SetDrawLevel(6)
	rowObject.sbtStats = stats

	if rowHeight and rowHeight > 0 then control:SetHeight(rowHeight) end
	-- Without the game's Damage/Heals/game-type cells the row is narrower too.
	control:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_WIDTH - SBT_REMOVED_ROW_WIDTH)
end

ZO_PostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "Initialize", sbt_addRowControls)
ZO_PostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "UpdateRow", sbt_refreshRow)

-- Window size: after the game's UpdateAll (which also runs after a keyboard/gamepad switch, when
-- the game re-applies its own templates). While hidden, UpdateAll only marks itself dirty.
ZO_PostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(scoreboard)
	sbt_applyScoreboardWidth(scoreboard)
	if scoreboard:IsShowing() then
		sbt_applyScoreboardHeight(scoreboard)
	end
end)

-------------------------------------------------------------------------------------------------
--  Built-in Battlegrounds screen: remember the selected mode  --
-------------------------------------------------------------------------------------------------
-- For when the built-in Battlegrounds screen is used (panel not replaced): its mode dropdown
-- forgets the choice on every reload. A choice clicked in the dropdown is saved, and put back
-- whenever the screen rebuilds its filters while it's showing. Hooked once the screen exists
-- (EVENT_PLAYER_ACTIVATED); the setting is checked inside the hooks, so it applies right away.
local function sbt_rememberBattlegroundMode()
	local finder = BATTLEGROUND_FINDER_KEYBOARD
	if sbt.modeHooksInstalled or not (finder and finder.filterComboBox) then return end
	sbt.modeHooksInstalled = true
	local modes = finder.filterComboBox

	ZO_PostHook(modes, "SelectItem", function(comboBox, item)
		-- Only the player's own pick: the dropdown is open. Refreshes select with it closed.
		if item and sbt.accountVars.saveVanillaBattlegroundMode and comboBox:IsDropdownVisible() then
			sbt.accountVars.lastSelectedBattlegroundMode = item.name
		end
	end)

	ZO_PostHook(finder, "RefreshFilters", function()
		local wanted = sbt.accountVars.saveVanillaBattlegroundMode and sbt.accountVars.lastSelectedBattlegroundMode
		if not wanted or not finder.fragment:IsShowing() then return end
		local selected = modes:GetSelectedItemData()
		if selected and selected.name == wanted then return end
		for _, item in ipairs(modes.m_sortedItems) do
			if item.name == wanted then
				modes:SelectItem(item)
				return
			end
		end
	end)
end


-------------------------------------------------------------------------------------------------
--  Group & Activity Finder: multi-queue panel  --
-------------------------------------------------------------------------------------------------
-- Lets you queue for several battleground types at once, like the gamepad UI does. Styled to
-- match the game's own activity-finder lists: real checkboxes with a hover highlight, and a
-- Join Queue / View Veterancy button pair at the bottom, both sharing the same content-area
-- anchors as the built-in category panels so everything lines up with them.


-- The battleground queues on offer: the "sets" (e.g. "4v4 Competitive - Solo") of every bracket
-- the character isn't level-locked out of, as long as they're active (event queues come and go).
local SBT_BATTLEGROUND_ACTIVITIES = {
	LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL,
	LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION,
	LFG_ACTIVITY_BATTLE_GROUND_CHAMPION,
}

function sbt.collectQueues()
	sbt.queues = {}
	for _, activityType in ipairs(SBT_BATTLEGROUND_ACTIVITIES) do
		if not ZO_ActivityFinderTemplate_Shared:GetLevelLockInfoByActivity(activityType) then
			for _, location in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType)) do
				if location:GetEntryType() == ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE.SET and location:IsActive() then
					sbt.queues[#sbt.queues + 1] = location
				end
			end
		end
	end
end


local SBT_ROW_HEIGHT = 30

-- Colors the qualifier part of a queue's display name, matching how these read in-game (gold for
-- Competitive, green for Standard/Weekly/Weekend, both configurable via the LAM2 panel) --
-- everything else (the team-size prefix, the "- Solo"/"- Group" suffix) is left at the row
-- label's own default color. Weekly/Weekend are matched case-insensitively (their exact in-game
-- capitalization isn't confirmed yet) while keeping whatever casing the game actually uses in the
-- displayed text (the "%0" replacement is the whole match, not a fixed-case literal).
local function sbt_floatToHex(r, g, b)
	return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function sbt_colorizeLocationName(rawName)
	local c = sbt.accountVars.competitiveColor
	local s = sbt.accountVars.standardColor
	local competitiveHex = sbt_floatToHex(c.r, c.g, c.b)
	local standardHex = sbt_floatToHex(s.r, s.g, s.b)

	local colored = rawName:gsub("Competitive", "|c" .. competitiveHex .. "Competitive|r")
	colored = colored:gsub("Standard", "|c" .. standardHex .. "Standard|r")
	colored = colored:gsub("[Ww][Ee][Ee][Kk][Ll][Yy]", "|c" .. standardHex .. "%0|r")
	colored = colored:gsub("[Ww][Ee][Ee][Kk][Ee][Nn][Dd]", "|c" .. standardHex .. "%0|r")
	return colored
end

-- Quick-queue grouping key: the queue's own name with the words "Solo"/"Group" (and whatever
-- separator/brackets they leave behind) taken out, e.g. "4v4 Competitive - Solo" and "4v4
-- Competitive - Group" -> "4v4 Competitive", "Big Team Battles (Solo)" -> "Big Team Battles".
-- Every queue sharing a key goes under one "<key>" button. Purely name-based on purpose: the
-- line-up changes with events (weeklies, holiday queues, new formats like 9v9 without any team
-- size in the name), and the name is the one thing every variant reliably shares. A queue
-- without a Solo/Group word just gets its own button.
local SBT_QUEUE_VARIANT_WORDS = { solo = true, group = true }

local function sbt_getQuickQueueKey(rawName)
	local key = rawName:gsub("%a+", function(word)
		if SBT_QUEUE_VARIANT_WORDS[word:lower()] then return "" end
	end)
	key = key:gsub("%(%s*%)", ""):gsub("%[%s*%]", "")
	key = key:gsub("%s+", " ")
	key = key:gsub("^[%s%-:/|,]+", ""):gsub("[%s%-:/|,]+$", "")
	if key == "" then return rawName end
	return key
end

-- Created on demand, reused across rebuilds (named controls can't be destroyed), so this only
-- grows to the most buttons ever needed in one session.
sbt.quickQueueButtons = {}
local SBT_QUICK_QUEUE_MAX_BUTTONS = 6
local SBT_QUICK_QUEUE_PER_ROW = 2
local SBT_QUICK_QUEUE_MIN_WIDTH = 200 -- same as Join Queue / View Veterancy
local SBT_QUICK_QUEUE_TEXT_PADDING = 40
local SBT_QUICK_QUEUE_GAP_X = 30 -- same gap as Join Queue / View Veterancy
local SBT_QUICK_QUEUE_GAP_Y = 10

-- Just the enabled/disabled visual state of the checklist checkboxes -- never touches selections,
-- so unlike sbt.refreshVisibleState's full resync, this is safe to call from broad status-change
-- listeners even when our own panel isn't the one currently open (e.g. the player queued from the
-- built-in Battlegrounds tab instead of ours -- same underlying locations/selections, so that
-- fires our callbacks too, and we still want our own checkboxes to reflect it without touching
-- whatever they selected over there).
-- A queue can be picked when the group fits it and the game hasn't locked it (not the group
-- leader, a group member below the level requirement, Group Finder in use, ...). Locked queues
-- can't be selected in the game either, so their checkbox is disabled instead of looking ticked
-- while nothing is actually selected.
local function sbt_isSelectable(location, groupSize)
	return groupSize <= location.maxGroupSize and not location:IsLocked()
end

-- Our ticked checkboxes (sbt.vars.selectedQueues) are what Join Queue queues for. The game keeps
-- its own copy of the selection and clears it on its own now and then (e.g. whenever the Group
-- Menu re-selects the Battlegrounds entry, or a group change refreshes the queue data), so it's
-- written again from ours right before queueing, rather than trusted to still match.
function sbt.applySelections()
	if IsCurrentlySearchingForGroup() then return end
	local groupSize = GetGroupSize()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:ClearSelections()
	for _, data in ipairs(sbt.rows) do
		local location = data.location
		if sbt.vars.selectedQueues[location.rawName] and sbt_isSelectable(location, groupSize) then
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, true)
		end
	end
end

local function sbt_isAnyQueueTicked()
	local groupSize = GetGroupSize()
	for _, data in ipairs(sbt.rows) do
		local location = data.location
		if sbt.vars.selectedQueues[location.rawName] and sbt_isSelectable(location, groupSize) then
			return true
		end
	end
	return false
end

function sbt.refreshRowEnabledState()
	local groupSize = GetGroupSize()
	-- Matches vanilla's own filter checkboxes (zo_activityfindertemplate_keyboard.lua
	-- InitializeNavigationList/TreeEntrySetup: "control.enabled = not isLocked and not
	-- IsCurrentlySearchingForGroup()") -- locked while actively searching/queued/mid ready check.
	-- Deliberately NOT gated on sbt.queueCooldownEndMs: the decline/timeout cooldown by itself
	-- must leave these clickable, only being actually in queue does not.
	local isSearching = IsCurrentlySearchingForGroup()
	for _, data in ipairs(sbt.rows) do
		local location = data.location
		local checkbox = data.control:GetNamedChild("Check")
		if isSearching or not sbt_isSelectable(location, groupSize) then
			ZO_CheckButton_Disable(checkbox)
		else
			ZO_CheckButton_Enable(checkbox)
		end
	end
end

-- Join Queue is enabled only when at least one queue is ticked, we're not already
-- searching/queued, and the Group Finder isn't in use -- the same conditions the built-in Join
-- Queue button uses (zo_activityfindertemplate_keyboard.lua RefreshButtons:
-- isJoinButtonEnabled), plus our own post-ready-check cooldown on top of that. The quick-queue
-- buttons don't need a queue already ticked (they tick their own), but they're just as unable to
-- do anything during those other conditions, so they grey out right along with Join Queue.
function sbt.refreshQueueButtonState()
	sbt.refreshRowEnabledState()

	local isCooldownActive = sbt.queueCooldownEndMs ~= nil
	local isCurrentlyInQueue = ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetIsCurrentlyInQueue()
	local isGroupFinderInUse = ZO_GroupFinder_IsGroupFinderInUse()

	local isQuickQueueEnabled = not (isCooldownActive or isCurrentlyInQueue or isGroupFinderInUse)
	for _, button in ipairs(sbt.quickQueueButtons) do
		button:SetEnabled(isQuickQueueEnabled)
	end

	if isCooldownActive then
		SBT_QueueButton:SetEnabled(false)
		return
	end

	local isJoinButtonEnabled = sbt_isAnyQueueTicked() and not isCurrentlyInQueue and not isGroupFinderInUse
	SBT_QueueButton:SetEnabled(isJoinButtonEnabled)
end

-- Shows the saved ticks on the checkboxes, writes them to the game's selection and refreshes which
-- checkboxes/buttons are usable. Run when the panel opens and when the queue list changes while
-- it's open.
function sbt.refreshVisibleState()
	for _, data in ipairs(sbt.rows) do
		local checkbox = data.control:GetNamedChild("Check")
		ZO_CheckButton_SetCheckState(checkbox, sbt.vars.selectedQueues[data.location.rawName] and true or false)
	end
	-- While queued the game's selection is what you're queued for: left alone (the game
	-- refuses changes then anyway), checkboxes locked like the built-in list does.
	sbt.applySelections()
	sbt.refreshQueueButtonState()
end

-- Rebuilds the checkbox rows from the current sbt.queues (see sbt.collectQueues -- a live query,
-- not a fixed list). Called once at startup and again whenever the game's own activity finder
-- data changes, so a queue that unlocks, gets added (e.g. a weekly), or disappears mid-session
-- shows up here without needing a /reloadui, the same as the built-in Battlegrounds tab.
-- ZO_ControlPool (not a plain CreateControlFromVirtual loop) is what makes rebuilding safe to
-- call more than once: ReleaseAllObjects() hides and reclaims the previous rows instead of
-- leaking a fresh set of named controls on every refresh.
function sbt.rebuildRows()
	sbt.rowPool:ReleaseAllObjects()
	sbt.rows = {}

	local last = SBT_PanelList

	for i, location in ipairs(sbt.queues) do
		local row = sbt.rowPool:AcquireObject()
		local checkbox = row:GetNamedChild("Check")
		row:GetNamedChild("Name"):SetText(sbt_colorizeLocationName(location.rawName))

		sbt.rows[i] = { control = row, location = location }

		row:SetAnchor(TOPLEFT, last, i == 1 and TOPLEFT or BOTTOMLEFT, 0, 0)
		last = row

		ZO_CheckButton_SetCheckState(checkbox, false)

		local queueName = location.rawName
		ZO_CheckButton_SetToggleFunction(checkbox, function(control, checked)
			-- Through the root manager (not location:SetSelected) so its selection count stays
			-- right for anything else reading it, e.g. the built-in panel.
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, checked)
			if checked then
				sbt.vars.selectedQueues[queueName] = true
			else
				sbt.vars.selectedQueues[queueName] = nil
			end
			sbt.refreshQueueButtonState()
		end)
	end

	SBT_PanelList:SetDimensions(360, math.max(#sbt.queues, 1) * SBT_ROW_HEIGHT)

	sbt.rebuildQuickQueueButtons()

	-- The panel might already be open when the queue list changes (e.g. a weekly queue turning
	-- on while you're sitting on this tab) -- re-sync the fresh rows immediately instead of
	-- waiting for the tab to be reopened.
	if not SBT_Panel:IsHidden() then
		sbt.refreshVisibleState()
	end
end

-- Rebuilds the "<name>" shortcut buttons above Join Queue / View Veterancy from the current
-- sbt.queues, same live data sbt.rebuildRows uses -- one button per quick-queue key (see
-- sbt_getQuickQueueKey), in the order the queues are listed, so whatever the game offers right now
-- (e.g. "4v4 Competitive" + "Big Team Battles", plus any event queue) gets a button without a
-- /reloadui. Laid out SBT_QUICK_QUEUE_PER_ROW per row, each row centered, extra rows stacking
-- upward from Join Queue (the container is anchored by its BOTTOM). Each button is as wide as
-- Join Queue, so a full row lines up exactly with Join Queue / View Veterancy below it; only a
-- label too long for that (e.g. a long event queue name) makes its button wider.
local function sbt_getQuickQueueButton(index)
	local button = sbt.quickQueueButtons[index]
	if not button then
		button = CreateControlFromVirtual("SBT_QuickQueueButton" .. index, SBT_PanelQuickQueueContainer, "SBT_QuickQueueButtonTemplate")
		sbt.quickQueueButtons[index] = button
	end
	return button
end

function sbt.rebuildQuickQueueButtons()
	for _, button in ipairs(sbt.quickQueueButtons) do
		button:SetHidden(true)
		button.quickQueueKey = nil
	end
	if not sbt.accountVars.showQuickQueueButtons then return end

	local keys = {}
	local seen = {}
	for _, location in ipairs(sbt.queues) do
		local key = sbt_getQuickQueueKey(location.rawName)
		if not seen[key] then
			seen[key] = true
			keys[#keys + 1] = key
			if #keys == SBT_QUICK_QUEUE_MAX_BUTTONS then break end
		end
	end
	if #keys == 0 then return end

	-- Label + width first, so every row can be centered on the widest one.
	local buttons = {}
	for i, key in ipairs(keys) do
		local button = sbt_getQuickQueueButton(i)
		button:SetText(key)
		button.quickQueueKey = key
		local label = button:GetLabelControl()
		local textWidth = label and label:GetTextWidth() or 0
		button:SetWidth(zo_max(SBT_QUICK_QUEUE_MIN_WIDTH, textWidth + SBT_QUICK_QUEUE_TEXT_PADDING))
		button:SetHidden(false)
		buttons[i] = button
	end

	local rows = {}
	local maxRowWidth = 0
	for i, button in ipairs(buttons) do
		local rowIndex = zo_floor((i - 1) / SBT_QUICK_QUEUE_PER_ROW) + 1
		local row = rows[rowIndex]
		if not row then
			row = { buttons = {}, width = -SBT_QUICK_QUEUE_GAP_X }
			rows[rowIndex] = row
		end
		row.buttons[#row.buttons + 1] = button
		row.width = row.width + SBT_QUICK_QUEUE_GAP_X + button:GetWidth()
		maxRowWidth = zo_max(maxRowWidth, row.width)
	end

	local y = 0
	for _, row in ipairs(rows) do
		local x = zo_floor((maxRowWidth - row.width) / 2)
		local rowHeight = 0
		for _, button in ipairs(row.buttons) do
			button:ClearAnchors()
			button:SetAnchor(TOPLEFT, SBT_PanelQuickQueueContainer, TOPLEFT, x, y)
			x = x + button:GetWidth() + SBT_QUICK_QUEUE_GAP_X
			rowHeight = zo_max(rowHeight, button:GetHeight())
		end
		y = y + rowHeight + SBT_QUICK_QUEUE_GAP_Y
	end
end

-- Selects every queue location that shares this quick-queue key (Solo and Group variants alike,
-- per the same grouping sbt.rebuildQuickQueueButtons uses), deselecting everything else, then
-- queues immediately -- one click instead of ticking the boxes by hand. sbt.refreshVisibleState
-- still applies the usual real-party-size gating on top of this, so e.g. the Solo variant isn't
-- selected while you're grouped.
function sbt.quickQueue(quickQueueKey)
	if not quickQueueKey then return end
	for _, data in ipairs(sbt.rows) do
		local location = data.location
		local queueName = location.rawName
		if sbt_getQuickQueueKey(queueName) == quickQueueKey then
			sbt.vars.selectedQueues[queueName] = true
		else
			sbt.vars.selectedQueues[queueName] = nil
		end
	end

	sbt.refreshVisibleState()
	sbt.joinQueue()
end

function sbt.createPanel()
	local fragment = ZO_FadeSceneFragment:New(SBT_Panel)

	-- Veterancy rank display (icon + rank + name + XP bar), same object the built-in
	-- Battlegrounds screen uses for its own VeterancyRank control.
	sbt.veterancyRankObject = ZO_VeterancyRank:New(SBT_PanelVeterancyRank)
	ZO_VETERANCY_MANAGER:RegisterCallback("OnVeterancyRankProgressed", function()
		sbt.veterancyRankObject:Refresh()
	end)

	sbt.rowPool = ZO_ControlPool:New("SBT_Row", SBT_PanelList, "SBT_Row")
	sbt.rebuildRows()

	-- Bonus rewards (sbt.refreshBonusInfo), under the queue list. ("Requeue automatically" is
	-- the clickable "Auto requeue: On/Off" line in the Finder's status block, see
	-- sbt_getAutoRequeueLabel.)
	local bonus = CreateControl("SBT_PanelBonus", SBT_Panel, CT_CONTROL)
	bonus:SetAnchor(TOPLEFT, SBT_PanelList, BOTTOMLEFT, 10, 20)
	bonus:SetDimensions(520, 80)
	local function BonusLabel(name, font, anchorTo)
		local label = CreateControl(name, bonus, CT_LABEL)
		label:SetFont(font)
		label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
		label:SetWidth(520)
		if anchorTo then
			label:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, 4)
		else
			label:SetAnchor(TOPLEFT, bonus, TOPLEFT, 0, 0)
		end
		return label
	end
	local bonusHeader = BonusLabel("SBT_PanelBonusHeader", "ZoFontWinH4")
	local bonusRewards = BonusLabel("SBT_PanelBonusRewards", "ZoFontGame", bonusHeader)
	BonusLabel("SBT_PanelBonusSolo", "ZoFontGame", bonusRewards)

	fragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING then
			SBT_PanelVeterancyRank:SetHidden(not IsVeterancySeasonActive())
			sbt.veterancyRankObject:Refresh()
			sbt.refreshVisibleState()
			sbt.refreshBonusInfo()
		end
	end)

	local queueButton = CreateControlFromVirtual("SBT_QueueButton", SBT_PanelButtonContainer, "SBT_QueueButtonTemplate")
	queueButton:SetAnchor(TOPLEFT)

	local viewVeterancyButton = CreateControlFromVirtual("SBT_ViewVeterancyButton", SBT_PanelButtonContainer, "SBT_ViewVeterancyButtonTemplate")
	-- Same anchor point and 30px gap the built-in Battlegrounds action bar uses between its own
	-- buttons (zo_activityfindertemplate_keyboard.lua RefreshButtons: SetAnchor(TOPLEFT, ..., TOPRIGHT, 30, 0)).
	viewVeterancyButton:SetAnchor(TOPLEFT, queueButton, TOPRIGHT, 30, 0)

	-- Keeps the Join Queue button's enabled state current: selections changing (including from
	-- outside our own panel, e.g. GetIsCurrentlyInQueue/GroupFinder) and entering/leaving the
	-- queue or a ready check both go through these same callbacks in the built-in game.
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnSelectionsChanged", sbt.refreshQueueButtonState)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnActivityFinderStatusUpdate", sbt.refreshQueueButtonState)

	sbt.panelFragment = fragment
	sbt.attachPanel()
end

function sbt.joinQueue()
	if sbt.queueCooldownEndMs then return end -- can't requeue during the post-ready-check-decline/timeout cooldown
	if IsCurrentlySearchingForGroup() then return end

	sbt.applySelections()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:StartSearch()
end

-- Mirrors the built-in "View Veterancy" button (zo_activityfindertemplate_keyboard.lua).
function sbt.viewVeterancy()
	VETERANCY_KEYBOARD:SetIsFromActivityFinder(true)
	SCENE_MANAGER:Push("VeterancySceneKeyboard")
end

-- Bonus rewards under the queue list. The daily bonus belongs to the activity (all
-- battlegrounds of your level bracket share it), not to one queue, so it's one line for the
-- whole list, worded like the built-in Battlegrounds screen's reward header. Below it, what the
-- reward is (same data the built-in screen lists), and the solo bonus if any Group queue offers
-- it (the built-in screen shows that for Group queues you join alone).
local SBT_BONUS_AVAILABLE_COLOR = "C59615"
local SBT_BONUS_NONE_COLOR = "8F8F8F"
local SBT_SOLO_BONUS_ICON = "EsoUI/Art/LFG/LFG_solo_bonus.dds"

function sbt.refreshBonusInfo()
	local rewardLocation, eligible, soloBonus = nil, false, false
	for _, location in ipairs(sbt.queues) do
		if location:HasRewardData() then
			if location:IsEligibleForDailyReward() then
				if not eligible then rewardLocation = location end
				eligible = true
			end
			rewardLocation = rewardLocation or location
		end
		if location:HasSoloBonus() then soloBonus = true end
	end

	if not rewardLocation then
		SBT_PanelBonusHeader:SetText("")
		SBT_PanelBonusRewards:SetText("")
	elseif eligible then
		SBT_PanelBonusHeader:SetText(string.format("|c%s%s|r", SBT_BONUS_AVAILABLE_COLOR, "Daily bonus reward: available"))
	else
		SBT_PanelBonusHeader:SetText(string.format("|c%s%s|r", SBT_BONUS_NONE_COLOR, "Daily bonus reward: already earned today"))
	end

	if rewardLocation then
		local rewardUIDataId, xpReward = rewardLocation:GetRewardData()
		local parts = {}
		if rewardUIDataId and rewardUIDataId ~= 0 then
			for nodeIndex = 1, GetNumLFGActivityRewardUINodes(rewardUIDataId) do
				local displayName, icon = GetLFGActivityRewardUINodeInfo(rewardUIDataId, nodeIndex)
				local text = zo_strformat(SI_ACTIVITY_FINDER_REWARD_NAME_FORMAT, displayName)
				if icon and icon ~= "" then text = zo_iconFormat(icon, 24, 24) .. " " .. text end
				parts[#parts + 1] = text
			end
		end
		if xpReward and xpReward > 0 then
			parts[#parts + 1] = zo_strformat(SI_ACTIVITY_FINDER_REWARD_XP_FORMAT, ZO_CommaDelimitNumber(xpReward))
		end
		local prefix = eligible and "Bonus reward: " or "Standard reward: "
		SBT_PanelBonusRewards:SetText(#parts > 0 and (prefix .. table.concat(parts, ", ")) or "")
	end

	if soloBonus then
		SBT_PanelBonusSolo:SetText(zo_iconFormat(SBT_SOLO_BONUS_ICON, 24, 24) .. " "
			.. zo_strformat("<<1>>: <<2>>", GetString(SI_ACTIVITY_FINDER_BATTLEGROUND_SOLO_BONUS_HEADER), GetString(SI_ACTIVITY_FINDER_BATTLEGROUND_SOLO_BONUS)))
	else
		SBT_PanelBonusSolo:SetText("")
	end
end

-- Puts the panel into the Group & Activity Finder: either in place of the built-in
-- Battlegrounds panel (its entry keeps the game's name, icon, position and level lock; only
-- what it opens changes), or as its own "Battleground Queue" entry. Needs both our panel and the
-- built-in Battlegrounds finder, which only exists once the in-game UI is up, so this is tried
-- from both places and only runs once. Switching between the two takes a /reloadui: the menu
-- builds its entries once.
function sbt.attachPanel()
	if sbt.panelAttached or not sbt.panelFragment then return end

	if sbt.accountVars.replaceBattlegroundsPanel then
		local finder = BATTLEGROUND_FINDER_KEYBOARD
		if not (finder and finder.categoryData and finder.fragment) then return end -- not up yet
		local battlegroundsFragment = finder.fragment
		finder.categoryData.categoryFragment = sbt.panelFragment
		-- Anything else in the game that opens the Battlegrounds panel by its fragment lands on
		-- the entry that now shows ours.
		local menu = GROUP_MENU_KEYBOARD
		local getNode = menu.GetTreeNodeByCategoryFragment
		menu.GetTreeNodeByCategoryFragment = function(self, fragment)
			if fragment == battlegroundsFragment then fragment = sbt.panelFragment end
			return getNode(self, fragment)
		end
		menu:RebuildCategories()
	else
		-- Same icons as the game's own Battlegrounds entry.
		local finderData = BATTLEGROUND_FINDER_KEYBOARD.categoryData
		GROUP_MENU_KEYBOARD:AddCategory({
			name = "Battleground Queue",
			categoryFragment = sbt.panelFragment,
			normalIcon = finderData.normalIcon,
			pressedIcon = finderData.pressedIcon,
			mouseoverIcon = finderData.mouseoverIcon,
			-- Right after Battlegrounds, ahead of Tales of Tribute -- see
			-- esoui/ingame/lfg/zo_activityfinderroot_manager.lua for the full priority table.
			priority = ZO_ACTIVITY_FINDER_SORT_PRIORITY.BATTLEGROUNDS + 10,
		})
	end
	sbt.panelAttached = true
end

-------------------------------------------------------------------------------------------------
--  Ready Check decline/timeout cooldown timer  --
-------------------------------------------------------------------------------------------------
-- When a battleground match is found, the base game pops up a ready check (a PLAYER_TO_PLAYER
-- accept/decline prompt) wherever you happen to be -- almost never with the Group & Activity
-- Finder window open, since that's not where the prompt appears. Declining it, or just not
-- responding until it expires, kicks you from the queue and the server briefly blocks you from
-- requeueing, with zero feedback about when you're allowed to queue again. Accepting the ready
-- check must NOT trigger any of this.
--
-- The "Status: Queued" / "Actual:" labels (ZO_SearchingForGroupStatus / ZO_SearchingForGroupAct-
-- ualTime) it replaces only exist inside that Group Menu window -- if that window is closed when
-- this fires, there's nothing to show it in (by design; a floating always-on-screen label was
-- tried and works, but ends up in a spot that doesn't match where you're used to looking).
-- It also disables this addon's own "Join Queue" button for the same duration.
--
-- Two ways this can start:
--  1. Explicit decline: the "Yes" button of the LFG_DECLINE_READY_CHECK_CONFIRMATION dialog
--     calls DeclineLFGReadyCheckNotification() directly (esoui/ingame/globals/ingamedialogs.lua)
--     -- hooked directly below for an immediate, reliable trigger.
--  2. Timing out with no response: there's no dedicated "expired" API call for that, so this
--     tracks the ready check state via EVENT_ACTIVITY_FINDER_STATUS_UPDATE, the same event the
--     base game's own SearchingForGroupManager uses (esoui/ingame/lfg/searchingforgroup.lua /
--     zo_activityfinderroot_manager.lua): status == ACTIVITY_FINDER_STATUS_READY_CHECK marks one
--     active. If it ends without either the decline hook or an explicit accept
--     (AcceptLFGReadyCheckNotification) having fired first, that means it expired.

local SBT_QUEUE_COOLDOWN_SECONDS = 30 -- change this if the real server-side lockout ever changes
local SBT_COOLDOWN_TEXT = "Requeue available in: %ds" -- edit to taste / translate

local SBT_COOLDOWN_UPDATE_NAME = "SBT_QueueCooldown"
local cooldownLabel

local function sbt_getCooldownLabel()
	if not cooldownLabel then
		-- Same spot the base game's own "Actual:" label (ZO_SearchingForGroupActualTime) uses.
		-- Trade-off, by design: this only shows up while the Group & Activity Finder window
		-- happens to be open.
		cooldownLabel = CreateControl("SBT_QueueCooldownLabel", SEARCHING_FOR_GROUP.control, CT_LABEL)
		cooldownLabel:SetFont("ZoFontHeader")
		cooldownLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
		cooldownLabel:SetAnchor(BOTTOM, SEARCHING_FOR_GROUP.leaveQueueButton, TOP, 0, -5)
		cooldownLabel:SetHidden(true)
	end
	return cooldownLabel
end

local function sbt_setVanillaLabelsHidden(hidden)
	SEARCHING_FOR_GROUP.statusLabel:SetHidden(hidden)
	SEARCHING_FOR_GROUP.actualTimeLabel:SetHidden(hidden)
	SEARCHING_FOR_GROUP.estimatedTimeLabel:SetHidden(hidden)
end

local autoRequeueLabel

local function sbt_getAutoRequeueLabel()
	if not autoRequeueLabel then
		-- One more row stacked above the base game's own "Status: Queued" label (same
		-- ZO_SearchingForGroup_StatusLabel look), so it reads as part of that same block instead
		-- of a bolted-on extra. Unlike the cooldown label above, this one is never hidden by us --
		-- it's meant to stay visible (and current) the whole time you're queued, cooldown or not.
		autoRequeueLabel = CreateControl("SBT_AutoRequeueLabel", SEARCHING_FOR_GROUP.control, CT_LABEL)
		autoRequeueLabel:SetFont("ZoFontHeader")
		autoRequeueLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
		autoRequeueLabel:SetAnchor(BOTTOM, SEARCHING_FOR_GROUP.statusLabel, TOP, 0, 0)
		-- Clicking it switches "Requeue automatically" (never saved: off after every reload).
		autoRequeueLabel:SetMouseEnabled(true)
		autoRequeueLabel:SetHandler("OnMouseEnter", function(control)
			control:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_HIGHLIGHT))
			InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -5, TOP)
			SetTooltipText(InformationTooltip, "Click to turn on or off.\n\nWhen on, declining a ready check queues you again for the same battlegrounds once the cooldown is over. "
				.. "A ready check that times out, or leaving the queue yourself, never does. Turns off on every reload.")
		end)
		autoRequeueLabel:SetHandler("OnMouseExit", function(control)
			control:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
			ClearTooltip(InformationTooltip)
		end)
		autoRequeueLabel:SetHandler("OnMouseUp", function(control, button, upInside)
			if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
				sbt.requeueAutomatically = not sbt.requeueAutomatically
				PlaySound(SOUNDS.DEFAULT_CLICK)
				sbt.refreshAutoRequeueLabel()
			end
		end)
	end
	return autoRequeueLabel
end

-- Called whenever sbt.requeueAutomatically changes, and again on every activity finder status
-- update (queueing, a ready check starting/ending, ...) so a toggle that happened before
-- SEARCHING_FOR_GROUP even existed yet still ends up showing the right text once it does.
function sbt.refreshAutoRequeueLabel()
	local label = sbt_getAutoRequeueLabel()
	if label then
		label:SetText("Auto requeue: " .. (sbt.requeueAutomatically and "|c00CC00On|r" or "Off"))
	end
end

-- Snapshot of sbt.vars.selectedQueues taken at the moment of an explicit decline (see
-- sbt_onDeclinedReadyCheck below) -- what "requeue automatically" requeues for once the cooldown
-- ends, regardless of whatever the checklist happens to show by then. Left nil by a timeout (see
-- sbt_onActivityFinderStatusUpdate), which is what keeps a timeout from ever auto-requeueing even
-- though it starts the same cooldown a decline does.
local pendingRequeueSelections = nil

local function sbt_endQueueCooldown()
	EVENT_MANAGER:UnregisterForUpdate(SBT_COOLDOWN_UPDATE_NAME)
	sbt.queueCooldownEndMs = nil

	local label = sbt_getCooldownLabel()
	if label then label:SetHidden(true) end

	sbt_setVanillaLabelsHidden(false)

	sbt.refreshQueueButtonState()

	-- Only ever set by an explicit decline, never by a timeout or a manual leave-queue (neither
	-- of those touches pendingRequeueSelections at all) -- so this only fires in the one case the
	-- checkbox's tooltip promises.
	if sbt.requeueAutomatically and pendingRequeueSelections then
		sbt.vars.selectedQueues = pendingRequeueSelections
		sbt.refreshVisibleState()
		sbt.joinQueue()
	end
	pendingRequeueSelections = nil
end

local function sbt_updateQueueCooldown()
	if not sbt.queueCooldownEndMs then return end

	local remainingMs = sbt.queueCooldownEndMs - GetFrameTimeMilliseconds()
	if remainingMs <= 0 then
		sbt_endQueueCooldown()
		return
	end

	local label = sbt_getCooldownLabel()
	if label then
		label:SetText(string.format(SBT_COOLDOWN_TEXT, math.ceil(remainingMs / 1000)))
	end
end

function sbt.startQueueCooldown()
	sbt.queueCooldownEndMs = GetFrameTimeMilliseconds() + (SBT_QUEUE_COOLDOWN_SECONDS * 1000)

	sbt_setVanillaLabelsHidden(true)

	local label = sbt_getCooldownLabel()
	if label then
		label:SetHidden(false)
	end

	sbt.refreshQueueButtonState()

	sbt_updateQueueCooldown()
	EVENT_MANAGER:RegisterForUpdate(SBT_COOLDOWN_UPDATE_NAME, 200, sbt_updateQueueCooldown)
end

local SBT_READY_CHECK_EVENT_NAME = "SBT_ReadyCheckWatcher"

local wasInReadyCheck = false
local respondedToReadyCheck = false -- set once we've explicitly accepted or declined the current one

local function sbt_onAcceptedReadyCheck()
	respondedToReadyCheck = true
end

local function sbt_onDeclinedReadyCheck()
	respondedToReadyCheck = true
	-- Captured now, not read back from sbt.vars.selectedQueues when the cooldown ends: the
	-- checklist (or the queue list itself) could change during the 30s wait, and "requeue
	-- automatically" is supposed to requeue for the same modes that were queued before the
	-- decline, not whatever's ticked by the time it fires.
	pendingRequeueSelections = ZO_ShallowTableCopy(sbt.vars.selectedQueues)
	sbt.startQueueCooldown()
end

-- EVENT_ACTIVITY_FINDER_STATUS_UPDATE(status) is what the base game's own SearchingForGroupManager
-- (esoui/ingame/lfg/searchingforgroup.lua, see ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback
-- ("OnActivityFinderStatusUpdate", ...) / esoui/ingame/lfg/zo_activityfinderroot_manager.lua)
-- listens to for this exact purpose, and it hands the new status directly as an argument -- no
-- need to separately poll GetActivityFinderStatus() and risk reading it before it's updated.
local function sbt_onActivityFinderStatusUpdate(status)
	local isInReadyCheck = (status == ACTIVITY_FINDER_STATUS_READY_CHECK)

	if isInReadyCheck and not wasInReadyCheck then
		-- A new ready check just started; reset tracking for it.
		respondedToReadyCheck = false
	elseif wasInReadyCheck and not isInReadyCheck then
		-- The ready check we were tracking just ended. The decline hook already starts the
		-- cooldown on its own and marks respondedToReadyCheck, so getting here with that still
		-- false means neither Accept nor Decline fired -- it expired on its own.
		if not respondedToReadyCheck then
			-- Expired with no response -- never auto-requeue for this one, only an explicit
			-- decline does (see sbt_onDeclinedReadyCheck).
			pendingRequeueSelections = nil
			sbt.startQueueCooldown()
		end
	end

	wasInReadyCheck = isInReadyCheck

	-- Catches SEARCHING_FOR_GROUP just now coming into existence (e.g. the checkbox got toggled
	-- before the player had ever queued this session, so sbt_getAutoRequeueLabel had nothing to
	-- attach to yet) as well as keeping the label itself in place across status changes.
	sbt.refreshAutoRequeueLabel()
end

EVENT_MANAGER:RegisterForEvent(SBT_READY_CHECK_EVENT_NAME, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(eventCode, status)
	sbt_onActivityFinderStatusUpdate(status)
end)

-- SecurePostHook is a native (non-Lua) API, so unlike ZO_PreHook/ZO_PostHook it needs the
-- table argument spelled out explicitly (_G) rather than defaulting it for a bare function name.
SecurePostHook(_G, "AcceptLFGReadyCheckNotification", sbt_onAcceptedReadyCheck)
SecurePostHook(_G, "DeclineLFGReadyCheckNotification", sbt_onDeclinedReadyCheck)

-------------------------------------------------------------------------------------------------
--  HUD activity tracker: time in queue  --
-------------------------------------------------------------------------------------------------
-- The game's activity tracker (the "Battlegrounds / Queued" box on the HUD) gets the time spent in
-- queue, the same "Actual" time the Group & Activity Finder shows: "Queued for 10:45". Updated
-- once a second while queued.
local SBT_TRACKER_TIMER_NAME = "SBT_ActivityTrackerTimer"

local function sbt_refreshTrackerTimer()
	local tracker = ACTIVITY_TRACKER
	if not tracker.activityType then return end
	local status = GetActivityFinderStatus()
	local text = GetString("SI_ACTIVITYFINDERSTATUS", status)
	if status == ACTIVITY_FINDER_STATUS_QUEUED and sbt.accountVars.queueTimerInTracker then
		local searchStartTimeMs = GetLFGSearchTimes()
		if searchStartTimeMs and searchStartTimeMs > 0 then
			local elapsedMs = zo_max(0, GetFrameTimeMilliseconds() - searchStartTimeMs)
			text = string.format("%s for %s", text, ZO_FormatTimeMilliseconds(elapsedMs, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR))
		end
	end
	tracker:SetSubLabelText(text)
end

local function sbt_hookActivityTracker()
	local tracker = ACTIVITY_TRACKER
	ZO_PostHook(tracker, "Update", function()
		local queued = GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_QUEUED and sbt.accountVars.queueTimerInTracker
		EVENT_MANAGER:UnregisterForUpdate(SBT_TRACKER_TIMER_NAME)
		if queued then
			EVENT_MANAGER:RegisterForUpdate(SBT_TRACKER_TIMER_NAME, 1000, sbt_refreshTrackerTimer)
		end
		sbt_refreshTrackerTimer()
	end)
	tracker:Update()
end
sbt.hookActivityTracker = sbt_hookActivityTracker

-------------------------------------------------------------------------------------------------
--  LibAddonMenu-2.0 settings panel  --
-------------------------------------------------------------------------------------------------
-- Optional: without LibAddonMenu-2.0 there is no panel, and every setting keeps whatever's in
-- SavedVariables (or the defaults above).

function sbt.registerSettingsPanel()
	local LAM = LibAddonMenu2
	if not LAM then return end

	local panelData = {
		type = "panel",
		name = sbt.title,
		displayName = sbt.title,
		author = "Schrodi",
		version = sbt.version,
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local optionsTable = {
		{
			type = "dropdown",
			name = "Player name display",
			tooltip = "How player names are shown on the battlegrounds scoreboard.",
			choices = {
				"Default (respect game settings)",
				"@UserID",
				"Character Name",
				"@UserID (Character Name)",
				"Character Name (@UserID)",
			},
			choicesValues = { "default", "userid", "charname", "userid_charname", "charname_userid" },
			getFunc = function() return sbt.accountVars.nameDisplayMode end,
			setFunc = function(value) sbt.accountVars.nameDisplayMode = value end,
			default = "default",
			width = "full",
		},
		{
			type = "checkbox",
			name = "Replace the Battlegrounds panel",
			tooltip = "The Group & Activity Finder's Battlegrounds entry opens this addon's multi-queue panel instead of the game's own (same name and icon). Off: the game's panel stays, and the multi-queue panel is a separate \"Battleground Queue\" entry.",
			getFunc = function() return sbt.accountVars.replaceBattlegroundsPanel end,
			setFunc = function(value) sbt.accountVars.replaceBattlegroundsPanel = value end,
			default = true,
			requiresReload = true,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Time in queue on the HUD",
			tooltip = "The game's activity tracker on the HUD (\"Battlegrounds / Queued\") shows how long you've been in queue, e.g. \"Queued for 10:45\".",
			getFunc = function() return sbt.accountVars.queueTimerInTracker end,
			setFunc = function(value)
				sbt.accountVars.queueTimerInTracker = value
				ACTIVITY_TRACKER:Update()
			end,
			default = true,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Remember last battleground mode in vanilla finder",
			tooltip = "On the built-in Battlegrounds queue screen (when it isn't replaced by this addon's panel), remember the mode dropdown's last selection and restore it automatically across UI reloads and relogs.",
			getFunc = function() return sbt.accountVars.saveVanillaBattlegroundMode end,
			setFunc = function(value) sbt.accountVars.saveVanillaBattlegroundMode = value end,
			default = true,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Show quick queue buttons",
			tooltip = "Show the \"Queue ...\" shortcut buttons on the multi-queue panel -- one per battleground queue on offer, each queueing its Solo and Group variants together.",
			getFunc = function() return sbt.accountVars.showQuickQueueButtons end,
			setFunc = function(value)
				sbt.accountVars.showQuickQueueButtons = value
				sbt.rebuildQuickQueueButtons()
			end,
			default = true,
			width = "full",
		},
		{
			type = "colorpicker",
			name = "Competitive queue color",
			tooltip = "Color used for \"Competitive\" in queue names.",
			getFunc = function()
				local c = sbt.accountVars.competitiveColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				sbt.accountVars.competitiveColor = { r = r, g = g, b = b, a = a or 1 }
				-- rowPool only exists once sbt.createPanel() has run (first OnUpdateLocationData
				-- callback) -- nothing to recolor yet if the setting's changed before that.
				if sbt.rowPool then sbt.rebuildRows() end
			end,
			default = { r = 0xC5 / 255, g = 0x96 / 255, b = 0x15 / 255, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Standard queue color",
			tooltip = "Color used for \"Standard\", \"Weekly\", and \"Weekend\" in queue names.",
			getFunc = function()
				local c = sbt.accountVars.standardColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				sbt.accountVars.standardColor = { r = r, g = g, b = b, a = a or 1 }
				if sbt.rowPool then sbt.rebuildRows() end
			end,
			default = { r = 0x00 / 255, g = 0xAA / 255, b = 0x00 / 255, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Healing Done color",
			tooltip = "Color of the Healing Done number on the battlegrounds scoreboard.",
			getFunc = function()
				local c = sbt.accountVars.healColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				sbt.accountVars.healColor = { r = r, g = g, b = b, a = a or 1 }
			end,
			default = { r = 1, g = 0.85, b = 0, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Damage Done color",
			tooltip = "Color of the Damage Done number on the battlegrounds scoreboard.",
			getFunc = function()
				local c = sbt.accountVars.damageColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				sbt.accountVars.damageColor = { r = r, g = g, b = b, a = a or 1 }
			end,
			default = { r = 1, g = 1, b = 1, a = 1 },
			width = "half",
		},
	}

	sbt.settingsPanel = LAM:RegisterAddonPanel(sbt.name .. "Options", panelData)
	LAM:RegisterOptionControls(sbt.name .. "Options", optionsTable)
end

-------------------------------------------------------------------------------------------------
--  Loading  --
-------------------------------------------------------------------------------------------------

-- One-time setup: builds the fragment, buttons and Group Menu category, which can only ever be
-- created once. After that, the queue list itself keeps refreshing -- see sbt.refreshQueues.
function sbt.onFirstLocationData()
	sbt.collectQueues()
	sbt.createPanel()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:UnregisterCallback("OnUpdateLocationData", sbt.onFirstLocationData)

	-- From here on the queue list stays live instead of freezing at whatever was active on
	-- login/reload: refreshed on the same triggers the built-in Battlegrounds tab uses for its
	-- own filter list (zo_activityfindertemplate_shared.lua RegisterEvents) -- location data
	-- changing, leveling up, switching campaigns, or a holiday/weekly event starting or ending.
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", sbt.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnLevelUpdate", sbt.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnCurrentCampaignChanged", sbt.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnHolidaysChanged", sbt.refreshQueues)
end

function sbt.refreshQueues()
	sbt.collectQueues()
	sbt.rebuildRows()
	if not SBT_Panel:IsHidden() then sbt.refreshBonusInfo() end
end

local function sbt_onLoaded()

	sbt.vars = ZO_SavedVars:NewCharacterIdSettings("SchrodisBattlegroundTools_SV", 1, nil, SBT_DEFAULTS)
	sbt.accountVars = ZO_SavedVars:NewAccountWide("SchrodisBattlegroundTools_SV", 1, "Settings", defaultAccountSettings)
	sbt.registerSettingsPanel()
	SLASH_COMMANDS["/sbt"] = function()
		if sbt.settingsPanel then
			LibAddonMenu2:OpenToPanel(sbt.settingsPanel)
		else
			CHAT_ROUTER:AddSystemMessage(sbt.title .. ": the settings need LibAddonMenu-2.0.")
		end
	end
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", sbt.onFirstLocationData)

	-- BATTLEGROUND_FINDER_KEYBOARD, ACTIVITY_TRACKER and the Finder's status block only exist once
	-- the in-game UI is up.
	EVENT_MANAGER:RegisterForEvent(sbt.name, EVENT_PLAYER_ACTIVATED, function()
		sbt_rememberBattlegroundMode()
		sbt.attachPanel()
		sbt_hookActivityTracker()
		sbt.refreshAutoRequeueLabel()
		EVENT_MANAGER:UnregisterForEvent(sbt.name, EVENT_PLAYER_ACTIVATED)
	end)
end

EVENT_MANAGER:RegisterForEvent(sbt.name, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= sbt.name then return end
	EVENT_MANAGER:UnregisterForEvent(sbt.name, EVENT_ADD_ON_LOADED)
	sbt_onLoaded()
end)
