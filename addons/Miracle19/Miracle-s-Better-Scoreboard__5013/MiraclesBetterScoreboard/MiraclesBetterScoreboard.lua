local bs = {}
-- Written by M0R_Gaming
-- Update 51 compatibility and scoreboard enhancements by @MlRACLE

bs.name = "MiraclesBetterScoreboard"
bs.scores = {}
bs.queues = {}
bs.vars = {}

-- Local references to frequently used ESO API constants (read after ESO initializes them).
local SCORE_TRACKER_TYPE_DAMAGE_DONE = SCORE_TRACKER_TYPE_DAMAGE_DONE
local SCORE_TRACKER_TYPE_HEALING_DONE = SCORE_TRACKER_TYPE_HEALING_DONE
local SCORE_TRACKER_TYPE_DAMAGE_TAKEN = SCORE_TRACKER_TYPE_DAMAGE_TAKEN
local SCORE_TRACKER_TYPE_KILL = SCORE_TRACKER_TYPE_KILL
local SCORE_TRACKER_TYPE_DEATH = SCORE_TRACKER_TYPE_DEATH
local SCORE_TRACKER_TYPE_ASSISTS = SCORE_TRACKER_TYPE_ASSISTS
local BATTLEGROUND_ALLIANCE_FIRE_DRAKES = BATTLEGROUND_ALLIANCE_FIRE_DRAKES
local BATTLEGROUND_ALLIANCE_PIT_DAEMONS = BATTLEGROUND_ALLIANCE_PIT_DAEMONS
local BATTLEGROUND_ALLIANCE_STORM_LORDS = BATTLEGROUND_ALLIANCE_STORM_LORDS

local classIcons = {
	"esoui/art/icons/class/gamepad/gp_class_dragonknight.dds",
	"esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
	"esoui/art/icons/class/gamepad/gp_class_nightblade.dds",
	"esoui/art/icons/class/gamepad/gp_class_warden.dds",
	"esoui/art/icons/class/gamepad/gp_class_necromancer.dds",
	"esoui/art/icons/class/gamepad/gp_class_templar.dds"
}

classIcons[117] = "esoui/art/icons/class/gamepad/gp_class_arcanist.dds"

local defaultSettings = {
	queueSelections = {},
	kda = {
		kills = 0,
		deaths = 0,
		assists = 0
	},
	wlt = {
		wins = 0,
		losses = 0,
		ties = 0
	},
	points = 0,
	damage = 0,
	heals = 0
}



local function getRoundIndex()
    local showAggregate = BATTLEGROUND_SCOREBOARD_FRAGMENT:ShouldShowAggregateScores()
    local roundIndex = showAggregate and GetCurrentBattlegroundRoundIndex() or BATTLEGROUND_SCOREBOARD_FRAGMENT.viewedRound
    return roundIndex, showAggregate
end

local function updateScore(i, roundIndex, showAggregate)
    local row = bs.scores[i]
    if not row then return end

    local damage = 0
    local heal = 0
    local damageTaken = 0
    if not showAggregate then
        damage = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex)
        heal = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex)
        damageTaken = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_DAMAGE_TAKEN, roundIndex)
    else
        damage = GetBattlegroundCumulativeScoreForScoreboardEntryByType(i, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex)
        heal = GetBattlegroundCumulativeScoreForScoreboardEntryByType(i, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex)
        damageTaken = GetBattlegroundCumulativeScoreForScoreboardEntryByType(i, SCORE_TRACKER_TYPE_DAMAGE_TAKEN, roundIndex)
    end

    damage = string.format("%sk", math.floor((damage or 0) / 1000))
    heal = string.format("%sk", math.floor((heal or 0) / 1000))

    -- Restore BetterScoreboard's stacked, extra damage/healing figures
    -- between Medal Score and K/D/A. Do not alter ESO's native right columns.
    local damageLabel = row.bsDamageLabel or row.damage
    local healLabel = row.bsHealLabel or row.heal
    if damageLabel then damageLabel:SetText(damage) end
    if healLabel then healLabel:SetText(heal) end
    if row.bsDamageTakenLabel then
        row.bsDamageTakenLabel:SetText(string.format("%sk", math.floor((damageTaken or 0) / 1000)))
    end
end

local function updateRow(row)
    if not row or not row.data then return end

    local data = row.data
    local nameLabel = row.nameLabel or (row.control and row.control:GetNamedChild("Name"))
    if not nameLabel then return end

    if data.isPlaceholderEntry then
        nameLabel:SetText("")
        if row.classIcon then row.classIcon:SetHidden(true) end
        if row.bsDamageLabel then row.bsDamageLabel:SetHidden(true) end
        if row.bsHealLabel then row.bsHealLabel:SetHidden(true) end
        if row.bsDamageTakenLabel then row.bsDamageTakenLabel:SetHidden(true) end
        if row.bsKDRatioLabel then row.bsKDRatioLabel:SetHidden(true) end
        return
    end

    local charName = zo_strformat(SI_PLAYER_NAME, data.characterName or "")
    local displayName = zo_strformat(SI_PLAYER_NAME, data.displayName or "")
    local formattedName
    if ZO_ShouldPreferUserId() then
        formattedName = string.format("%s (%s)", displayName, charName)
    else
        formattedName = string.format("%s (%s)", charName, displayName)
    end
    nameLabel:SetText(formattedName)
    if row.bsDamageLabel then row.bsDamageLabel:SetHidden(false) end
    if row.bsHealLabel then row.bsHealLabel:SetHidden(false) end
    if row.bsDamageTakenLabel then row.bsDamageTakenLabel:SetHidden(false) end
    if row.bsKDRatioLabel then
        local kills = tonumber(data.kills) or 0
        local deaths = tonumber(data.deaths) or 0
        -- Match the native Assists column typography and color exactly.
        if row.assistsLabel then
            row.bsKDRatioLabel:SetFont(row.assistsLabel:GetFont())
            row.bsKDRatioLabel:SetColor(row.assistsLabel:GetColor())
            row.bsKDRatioLabel:SetHeight(row.assistsLabel:GetHeight())
        end
        row.bsKDRatioLabel:SetText(string.format("%.2f", kills / math.max(deaths, 1)))
        row.bsKDRatioLabel:SetHidden(false)
    end

    if row.classIcon and data.entryIndex then
        local classId = GetScoreboardEntryClassId(data.entryIndex, data.roundIndex)
        row.classIcon:SetTexture(classIcons[classId] or "/esoui/art/icons/heraldrycrests_misc_blank_01.dds")
        row.classIcon:SetHidden(false)
    end
end

-- ESO displays remaining lives in Deathmatch rounds, occupying the same
-- space as our class icon. Move only the native lives label to the left.
local function separateDeathmatchLives(row)
    if not row or not row.livesLabel or not row.data or not row.data.showLives then return end
    -- Preserve ESO's layout anchors: the player name/class positions can
    -- depend on the lives label. Move the rendered label only.
    row.livesLabel:SetTransformOffsetX(-44)
end

local function ensureClassIcon(row)
    if not row or row.classIcon then return end
    local control = row.control
    local nameLabel = row.nameLabel or (control and control:GetNamedChild("Name"))
    if not control or not nameLabel then return end

    local classIcon = CreateControl(control:GetName().."MBSClassIcon", control, CT_TEXTURE)
    classIcon:SetAnchor(RIGHT, nameLabel, LEFT, -8, 0)
    classIcon:SetDrawLevel(6)
    row.classIcon = classIcon
end

-- The original addon displayed damage above gold healing as two extra
-- mini-labels in the gap between medal score and the K/D/A columns.
-- U51's new row class provides the medal label directly.
local function ensureStackedStats(row)
    if not row or not row.control then return end
    local medal = row.medalScoreLabel or row.control:GetNamedChild("MedalScore")
    if not medal then return end

    if not row.bsDamageLabel then
        local label = CreateControl(row.control:GetName() .. "MBSDamageScore", row.control, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetDimensions(52, 17)
        label:SetDrawLevel(7)
        row.bsDamageLabel = label
    end
    if not row.bsHealLabel then
        local label = CreateControl(row.control:GetName() .. "MBSHealScore", row.control, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetDimensions(52, 17)
        label:SetColor(1, 0.85, 0, 1)
        label:SetDrawLevel(7)
        row.bsHealLabel = label
    end

    -- Re-anchor after the stock style is applied, since rows are pooled and
    -- may switch between standard and compact templates.
    row.bsDamageLabel:ClearAnchors()
    row.bsDamageLabel:SetAnchor(RIGHT, medal, RIGHT, 75, -8)
    row.bsHealLabel:ClearAnchors()
    row.bsHealLabel:SetAnchor(RIGHT, medal, RIGHT, 75, 8)

    -- Damage received (red), restored to the left of the damage/healing pair.
    if not row.bsDamageTakenLabel then
        local label = CreateControl(row.control:GetName() .. "MBSDamageTakenScore", row.control, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetDimensions(40, 17)
        label:SetColor(1, 0.22, 0.22, 1)
        label:SetDrawLevel(7)
        row.bsDamageTakenLabel = label
    end
    row.bsDamageTakenLabel:ClearAnchors()
    row.bsDamageTakenLabel:SetAnchor(RIGHT, row.bsDamageLabel, LEFT, 3, 0)

    -- Reuse the now-hidden rightmost native statistic space for K/D.
    if row.gameTypeScoreLabel then
        if not row.bsKDRatioLabel then
            local label = CreateControl(row.control:GetName() .. "MBSKDRatio", row.control, CT_LABEL)
            label:SetFont("ZoFontGame")
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetDimensions(54, 24)
            label:SetDrawLevel(7)
            row.bsKDRatioLabel = label
        end
        row.bsKDRatioLabel:ClearAnchors()
        row.bsKDRatioLabel:SetAnchor(CENTER, row.assistsLabel, CENTER, 80, 0)
    end
end

-- Fit the *complete* team list in the scoreboard viewport. ESO normally caps
-- its scroll container at 680px, even when 18 player rows need more room.
-- Preserve the stock team panels, interactions, sorting, and match breakdown.
local function fitAllScoreboardPlayers(fragment)
    if not fragment or not fragment.panelContainer or not fragment.backgroundsContainer then return end
    local battlegroundId = fragment.currentBattlegroundId
    if not battlegroundId or battlegroundId == 0 then return end
    local teamCount = GetBattlegroundNumTeams(battlegroundId)
    local teamSize = GetBattlegroundTeamSize(battlegroundId)
    if not teamCount or not teamSize or teamCount < 1 or teamSize < 1 then return end
    if not ZO_Battleground_Scoreboard_Team_Panel_Object then return end

    local teamHeight = ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight(teamSize)
    if not teamHeight then return end
    local between = ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y or 10
    local desiredHeight = teamHeight * teamCount + between * (teamCount - 1) + 34
    local headerHeight = ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEIGHT or 90
    local paddingHeight = ZO_BATTLEGROUND_SCOREBOARD_PADDING_HEIGHT or 30
    local backgroundsHeight = desiredHeight + headerHeight + paddingHeight * 2

    fragment.panelContainer:SetHeight(desiredHeight)
    fragment.backgroundsContainer:SetHeight(backgroundsHeight)

    -- The base game shifts rounds mode upward to accommodate its scroll cap.
    -- Recenter the fully expanded list rather than retaining that offset.
    fragment.backgroundsContainer:ClearAnchors()
    local x = IsInGamepadPreferredMode() and -10 or 0
    fragment.backgroundsContainer:SetAnchor(CENTER, fragment.control, CENTER, x, -20)

    -- Scale the complete stock scoreboard (including its match-breakdown panel)
    -- if the screen isn't tall enough for all 18 rows at native size.
    -- Leave space for round controls and the bottom keybind strip.
    local screenHeight = GuiRoot:GetHeight()
    local availableHeight = screenHeight * 0.85
    local requiredHeight = backgroundsHeight + 110
    local scale = math.min(1, availableHeight / requiredHeight)
    fragment.control:SetScale(scale)

    -- With the entire team list visible, a scroll bar is unnecessary.
    fragment.panelContainer:SetScrollIndicatorEnabled(false)
end

if BATTLEGROUND_SCOREBOARD_FRAGMENT then
    SecurePostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", fitAllScoreboardPlayers)
end

-- Hide only the three native rightmost scoreboard columns. These values
-- remain in the game data; BetterScoreboard's custom stats are unaffected.
local function hideNativeRightColumns(row)
    if not row then return end
    -- Create breathing room for Medal Score / Damage Taken / Damage + Healing.
    -- The K/D ratio remains anchored to Assists and follows its new position.
    for _, label in ipairs({ row.killsLabel, row.deathsLabel, row.assistsLabel }) do
        if label then label:SetTransformOffsetX(30) end
    end
    if row.damageLabel then row.damageLabel:SetHidden(true) end
    if row.healsLabel then row.healsLabel:SetHidden(true) end
    if row.gameTypeScoreLabel then row.gameTypeScoreLabel:SetHidden(true) end
end

local function hideNativeRightHeaders(fragment)
    if not fragment or not fragment.headers then return end
    for _, suffix in ipairs({ "Kills", "Deaths", "Assists" }) do
        local control = fragment.headers:GetNamedChild(suffix)
        if control then control:SetTransformOffsetX(30) end
    end
    for _, suffix in ipairs({ "Damage", "Heals", "GameTypeScore" }) do
        local control = fragment.headers:GetNamedChild(suffix)
        if control then control:SetHidden(true) end
    end
    local nativeHeader = fragment.headers:GetNamedChild("GameTypeScore")
    if nativeHeader then
        if not fragment.bsKDRatioHeader then
            local label = CreateControl(fragment.headers:GetName() .. "MMBSKDRatioHeader", fragment.headers, CT_LABEL)
            label:SetFont("ZoFontGameBold")
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetDimensions(54, 28)
            label:SetText("K/D")
            fragment.bsKDRatioHeader = label
        end
        local assistsHeader = fragment.headers:GetNamedChild("Assists")
        if assistsHeader then
            fragment.bsKDRatioHeader:SetFont(assistsHeader:GetFont())
            fragment.bsKDRatioHeader:SetColor(assistsHeader:GetColor())
            fragment.bsKDRatioHeader:SetHeight(assistsHeader:GetHeight())
        end
        fragment.bsKDRatioHeader:ClearAnchors()
        fragment.bsKDRatioHeader:SetAnchor(CENTER, assistsHeader, CENTER, 80, 0)
        fragment.bsKDRatioHeader:SetHidden(false)
    end
end

-- Update 51 / API 101051 scoreboard implementation.
-- 6v6v6 contains 18 players, so ESO automatically switches to its compact
-- player-row template. Hook that current row object and size our class icon to
-- match the compact row; restore the original stacked damage/heal stats.
if ZO_Battleground_Scoreboard_Player_Row_Object then
    SecurePostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "SetupOnAcquire", function(self, panel, poolKey, data)
        ensureClassIcon(self)
        ensureStackedStats(self)
        local small = panel and panel.ShouldUseSmallPlayerEntries and panel:ShouldUseSmallPlayerEntries()
        if self.classIcon then
            local size = small and 24 or 30
            self.classIcon:SetDimensions(size, size)
        end
        updateRow(self)
        separateDeathmatchLives(self)
        hideNativeRightColumns(self)
    end)

    SecurePostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "UpdateRow", function(self)
        updateRow(self)
        separateDeathmatchLives(self)
        hideNativeRightColumns(self)
    end)

    SecurePostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(self)
        hideNativeRightHeaders(self)
        local roundIndex, showAggregate = getRoundIndex()
        bs.scores = {}
        for _, data in pairs(self.playerEntryData or {}) do
            if data.entryIndex and data.rowObject then
                bs.scores[data.entryIndex] = data.rowObject
                updateRow(data.rowObject)
                updateScore(data.entryIndex, roundIndex, showAggregate)
            end
        end
    end)

-- Legacy branch retained so the addon still works on older clients that used
-- the pre-Update-51 row class.
elseif Battleground_Scoreboard_Player_Row then
    SecurePostHook(Battleground_Scoreboard_Player_Row, "UpdateRow", updateRow)

    SecurePostHook(Battleground_Scoreboard_Player_Row, "Initialize", function(self, row)
        local rowName = row:GetName()
        local medalScore = row:GetNamedChild("MedalScore")
        local nameLabel = row:GetNamedChild("NameLabel")

        local damage = CreateControl(rowName.."MBSDamageScore", row, CT_LABEL)
        local heal = CreateControl(rowName.."MBSHealScore", row, CT_LABEL)
        heal:SetAnchor(LEFT, medalScore, RIGHT, 15, 0, 0)
        damage:SetAnchor(LEFT, medalScore, RIGHT, 15, 0, 0)
        heal:SetTransformOffsetY(15)
        damage:SetTransformOffsetY(-5)
        heal:SetColor(1, 0.85, 0)
        damage:SetFont("ZoFontGame")
        heal:SetFont("ZoFontGame")

        local classIcon = CreateControl(rowName.."MBSClassIcon", row, CT_TEXTURE)
        classIcon:SetAnchor(RIGHT, nameLabel, LEFT, -15, 0, 0)
        classIcon:SetDimensions(32, 32)
        classIcon:SetDrawLevel(6)

        self.damage = damage
        self.heal = heal
        self.classIcon = classIcon
    end)

    SecurePostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(self)
        local roundIndex, showAggregate = getRoundIndex()
        bs.scores = {}
        for _, v in pairs(self.playerEntryData or {}) do
            if v.entryIndex and v.rowObject then
                bs.scores[v.entryIndex] = v.rowObject
                updateRow(v.rowObject)
                updateScore(v.entryIndex, roundIndex, showAggregate)
            end
        end
    end)

    SecurePostHook(Battleground_Scoreboard_Player_Row, "SetupOnAcquire", function(self, panel, poolKey, data)
        local roundIndex, showAggregate = getRoundIndex()
        for i = 1, GetNumScoreboardEntries() do
            local _, name = GetScoreboardEntryInfo(i)
            if name == data.displayName then
                bs.scores[i] = self
                updateScore(i, roundIndex, showAggregate)
            end
        end
    end)
end


function bs.somethingChanged(code)
	-- logic used in base game BATTLEGROUND_SCOREBOARD_FRAGMENT to identify round index. Hopefully it just works without any issues
	local showAggregate = BATTLEGROUND_SCOREBOARD_FRAGMENT:ShouldShowAggregateScores()
	local roundIndex = showAggregate and GetCurrentBattlegroundRoundIndex() or BATTLEGROUND_SCOREBOARD_FRAGMENT.viewedRound
	
	for i=1,GetNumScoreboardEntries() do
		updateScore(i, roundIndex, showAggregate)
	end
end




function bs.buildQueues()


	-- Code that I adapted from zos's activity finder
	local filterModeData = ZO_ActivityFinderFilterModeData:New(LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL, LFG_ACTIVITY_BATTLE_GROUND_CHAMPION, LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION)
    filterModeData:SetSubmenuFilterNames(GetString(SI_BATTLEGROUND_FINDER_SPECIFIC_FILTER_TEXT), GetString(SI_BATTLEGROUND_FINDER_RANDOM_FILTER_TEXT))
    filterModeData:SetVisibleEntryTypes(ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE.SET)

	for _, activityType in ipairs(filterModeData:GetActivityTypes()) do
		if ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetNumLocationsByActivity(activityType, filterModeData:GetVisibleEntryTypes()) > 0 then
			local isLocked = ZO_ActivityFinderTemplate_Shared:GetLevelLockInfoByActivity(activityType)
			if not isLocked then
				local locationsData = ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType)
				for _, location in ipairs(locationsData) do
					if filterModeData:IsEntryTypeVisible(location:GetEntryType()) and location:IsActive() then
						bs.queues[#bs.queues+1] = location
					end
				end
			end
		end
	end
end

function bs.buildPanel()
	local fragment = ZO_FadeSceneFragment:New(MiraclesBetterScoreboard_Panel)

	--[[
	self:InitKeybindStrip()
	fragment:RegisterCallback("StateChange",  function(oldState, newState)
					   if(newState == SCENE_SHOWING) then
					      KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
					   elseif(newState == SCENE_HIDDEN) then
					      KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
					   end
	end)
	--]]

	
	




	local checkValues = {
		[TRISTATE_CHECK_BUTTON_UNCHECKED] = false,
		[TRISTATE_CHECK_BUTTON_CHECKED] = true
	}


	local last = MiraclesBetterScoreboard_PanelData
	local offset = 0


	local rows = {}

	for i,location in ipairs(bs.queues) do

		local row = CreateControlFromVirtual("MiraclesBetterScoreboard_Row"..i,MiraclesBetterScoreboard_PanelData,"MiraclesBetterScoreboard_Row")
		local checkbox = row:GetNamedChild("Check")
		row:GetNamedChild("Name"):SetText(location.rawName)

		rows[i] = {row,location}

		ZO_TriStateCheckButton_SetState(checkbox, TRISTATE_CHECK_BUTTON_UNCHECKED)
		ZO_TriStateCheckButton_SetStateChangeFunction(checkbox, function(control, checkState)
			
			--d("Row ".. i.. " has become "..tostring(checkValues[checkState]))

			local setState = checkValues[checkState]
			local locationName = location.rawName

			location:SetSelected(setState)
			if setState then
				bs.vars.queueSelections[locationName] = true
			elseif (not setState) and (bs.vars.queueSelections[locationName]) then
				bs.vars.queueSelections[locationName] = nil
			end

		end)

		row:SetAnchor(TOPCENTER, last, BOTTOMCENTER, 0, offset)
		last = row
		offset = 20

	end

	local button = CreateControlFromVirtual("MiraclesBetterScoreboard_QueueButton", MiraclesBetterScoreboard_PanelData, "MiraclesBetterScoreboard_QueueButtonTemplate")
	button:SetAnchor(TOPLEFT, last, BOTTOMLEFT, 0, 10)
	-- Keep the queue click callback in Lua, so no global addon table is needed by XML.
	button:SetHandler("OnClicked", bs.startSearch)




	fragment:RegisterCallback("StateChange",  function(oldState, newState)
		if(newState == SCENE_SHOWING) then
			local groupSize = GetGroupSize()
			-- Make the solo boxes auto selected if solo, group if in a group
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:ClearSelections()
			for i,data in ipairs(rows) do
				local checkbox = data[1]:GetNamedChild("Check")
				local location = data[2]
				local locationName = location.rawName


				ZO_CheckButton_Enable(checkbox)

				local state = TRISTATE_CHECK_BUTTON_UNCHECKED

				--[[ -- Old logic regarding queue selection
				if (location.minGroupSize <= groupSize and location.maxGroupSize >= groupSize) or
					(location.minGroupSize >= location.maxGroupSize and groupSize == 0) then
						state = TRISTATE_CHECK_BUTTON_CHECKED
				end
				--]]
				if bs.vars.queueSelections[locationName] then
					state = TRISTATE_CHECK_BUTTON_CHECKED
				end

				ZO_TriStateCheckButton_SetState(checkbox, state)
				if groupSize > location.maxGroupSize then
					ZO_CheckButton_Disable(checkbox)
					data[2]:SetSelected(false)
				else
					data[2]:SetSelected(checkValues[state])
				end



			end
		end
   end)





	GROUP_MENU_KEYBOARD:AddCategory({
		name = "Better Scoreboard",--"Lilith's Group Manager",
		categoryFragment = fragment,
		normalIcon = "esoui/art/journal/journal_tabicon_achievements_up.dds",
		--normalIcon = "EsoUI/Art/Icons/guildranks/guild_indexicon_leader_up.dds",
		pressedIcon = "esoui/art/journal/journal_tabicon_achievements_down.dds",
		mouseoverIcon = "esoui/art/journal/journal_tabicon_achievements_over.dds",
		priority = 400
	})
	--if LGM.SV.autoSelectLGM then
	--GROUP_MENU_KEYBOARD.navigationTree:SelectNode(GROUP_MENU_KEYBOARD.categoryFragmentToNodeLookup[fragment])


end



function bs.startSearch()
	if not IsCurrentlySearchingForGroup() then
		ZO_ACTIVITY_FINDER_ROOT_MANAGER:StartSearch()
	end
end




bs.currentName = ""

-- Save statistics after bg ends

function bs.bgEnded(eventCode, previousState, currentState)

	-- Change the bg name on the sidebar
	local name = GetString("SI_BATTLEGROUNDGAMETYPE", GetBattlegroundGameType(GetCurrentBattlegroundId()))
	if not (name == bs.currentName) then 
		bs.currentName = name
		if IsInGamepadPreferredMode() then
			BATTLEGROUND_MATCH_INFO_GAMEPAD.control:GetNamedChild("ContainerTitle"):SetText(name)
		else
			BATTLEGROUND_MATCH_INFO_KEYBOARD.control:GetNamedChild("ContainerTitle"):SetText(name)
		end
	end

	--d("BG State Changed: "..previousState.. " going to "..currentState)
	if (currentState == BATTLEGROUND_STATE_POSTGAME) then
		local player = GetScoreboardPlayerEntryIndex()
		bs.vars.damage = bs.vars.damage + GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_DAMAGE_DONE)
		bs.vars.heals = bs.vars.heals + GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_HEALING_DONE)
		--d("Damage: ".. GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_DAMAGE_DONE))
		--d("Heals: ".. GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_HEALING_DONE))
		--d("Kills: ".. GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_KILL))
		--d("Deaths: ".. GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_DEATH))
		--d("Assists: ".. GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_ASSISTS))
		local kda = bs.vars.kda

		kda.kills = kda.kills + GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_KILL)
		kda.deaths = kda.deaths + GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_DEATH)
		kda.assists = kda.assists + GetScoreboardEntryScoreByType(player, SCORE_TRACKER_TYPE_ASSISTS)

		local fire = GetCurrentBattlegroundScore(BATTLEGROUND_ALLIANCE_FIRE_DRAKES)
		local pit = GetCurrentBattlegroundScore(BATTLEGROUND_ALLIANCE_PIT_DAEMONS)
		local storm = GetCurrentBattlegroundScore(BATTLEGROUND_ALLIANCE_STORM_LORDS)
		local playerAlliance = GetUnitBattlegroundAlliance('player')

		local places = {}

		if (fire > pit) and (fire > storm) then
			places[BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = 1

			if (pit > storm) then
				places[BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = 2
				places[BATTLEGROUND_ALLIANCE_STORM_LORDS] = 3
			else
				places[BATTLEGROUND_ALLIANCE_STORM_LORDS] = 2
				places[BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = 3
			end

		elseif (pit > fire) and (pit > storm) then
			places[BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = 1

			if (fire > storm) then
				places[BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = 2
				places[BATTLEGROUND_ALLIANCE_STORM_LORDS] = 3
			else
				places[BATTLEGROUND_ALLIANCE_STORM_LORDS] = 2
				places[BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = 3
			end

		else
			places[BATTLEGROUND_ALLIANCE_STORM_LORDS] = 1

			if (fire > pit) then
				places[BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = 2
				places[BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = 3
			else
				places[BATTLEGROUND_ALLIANCE_PIT_DAEMONS] = 2
				places[BATTLEGROUND_ALLIANCE_FIRE_DRAKES] = 3
			end

		end

		--[[
		wlt = {
			wins = 0,
			losses = 0,
			ties = 0
		},
		]]


		local wlt = bs.vars.wlt

		--d("Place: ".. places[playerAlliance])
		if (places[playerAlliance] == 1) then
			wlt.wins = wlt.wins + 1
		elseif (places[playerAlliance] == 2) then
			wlt.ties = wlt.ties + 1
		else
			wlt.losses = wlt.losses + 1
		end
	end
end




function bs.updateLocations()
	bs.buildQueues()
	bs.buildPanel()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:UnregisterCallback("OnUpdateLocationData", bs.updateLocations)
end




-- The following was adapted from https://wiki.esoui.com/Circonians_Stamina_Bar_Tutorial#lua_Structure

-------------------------------------------------------------------------------------------------
--  OnAddOnLoaded  --
-------------------------------------------------------------------------------------------------
function bs.OnAddOnLoaded(event, addonName)
	if addonName ~= bs.name then return end

	bs:Initialize()
end
 
-------------------------------------------------------------------------------------------------
--  Initialize Function --
-------------------------------------------------------------------------------------------------
function bs:Initialize()
	EVENT_MANAGER:UnregisterForEvent(bs.name, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(bs.name, EVENT_BATTLEGROUND_SCOREBOARD_UPDATED, bs.somethingChanged)


	--commenting out statistic collection until further notice (when i feel like updating it); its not like it was even being shown previously
	--EVENT_MANAGER:RegisterForEvent(bs.name, EVENT_BATTLEGROUND_STATE_CHANGED, bs.bgEnded)
	
	bs.vars = ZO_SavedVars:NewCharacterIdSettings("MiraclesBetterScoreboardVars", 2, nil, defaultSettings)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", bs.updateLocations)
end
 
-------------------------------------------------------------------------------------------------
--  Register Events --
-------------------------------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(bs.name, EVENT_ADD_ON_LOADED, bs.OnAddOnLoaded)