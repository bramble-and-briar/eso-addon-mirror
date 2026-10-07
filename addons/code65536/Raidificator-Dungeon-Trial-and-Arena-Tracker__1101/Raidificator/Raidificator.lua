local LCCC = LibCodesCommonCode
local LEJ = LibExtendedJournal

LEJ.Used = true

Raidificator = {
	name = "Raidificator",

	title = GetString(SI_RCR_TITLE),
	url = "https://www.esoui.com/downloads/info1101.html",

	pollingInterval = 500, -- 0.5 seconds

	-- Default settings
	defaults = {
		migration = 0,

		-- Status
		left = 0,
		top = 0,
		zoneId = 0,
		startTime = 0,
		bgColor = 0x00000066,

		-- History
		contentId = "1R",
		allAccounts = true,
		hideArc1 = false,

		-- Achievements
		achCategoryId = 1,
		filterPledges = false,

		-- Logging
		autoLog = { false, false, false },

		-- Quest Handler
		quests = { D = 0, T = 0, A = 0 },

		-- Cast Blocker
		castBlocker = false,
	},

	MODE_INACTIVE = 0,
	MODE_DUNGEON = 1,
	MODE_TRIAL = 2,
	MODE_ENDLESS = 3,

	specialZone = false,

	statusElements = { },
	statusMode = 0,
	statusVisible = false,

	loggingEnabled = false,

	-- Dungeons
	condition = 0,
	speedrun = 0,
	lastQueue = 0,

	-- Trials
	raidId = 0,
	vitality = 0,
	vitalityMax = 0,
	targetTime = 0,
}
local RCR = Raidificator

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= RCR.name) then return end

	EVENT_MANAGER:UnregisterForEvent(RCR.name, EVENT_ADD_ON_LOADED)

	RCR.vars = ZO_SavedVars:NewAccountWide("RaidificatorSavedVariablesEx", 1, nil, RCR.defaults, nil, "$InstallationWide")

	-- Initialize history
	if (not RaidificatorHistory) then RaidificatorHistory = { } end
	RCR.history = RaidificatorHistory
	if (not RCR.history.clears) then RCR.history.clears = { } end
	if (not RCR.history.chars) then RCR.history.chars = { } end
	if (not RCR.history.notes) then RCR.history.notes = { } end

	RCR.MigrateData()
	RCR.RegisterSettingsPanel()
	RCR.InitializeStatus()
	RCR.InitializeHistory()
	RCR.InitializeAchievements()
	RCR.DTR.Initialize()
	RCR.InitializeLeaveInstance()
	RCR.InitializeQuestHandler()
	RCR.InitializePledges()

	LCCC.RunAfterInitialLoadscreen(RCR.CheckObsolete)

	if (RCR.HookTrialItemTooltips) then
		LCCC.RunAfterInitialLoadscreen(RCR.HookTrialItemTooltips)
	end
end


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

function RCR.Msg( text )
	CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", RCR.title, text))
end

function RCR.RequestDataFlush( )
	GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(RCR.name)
end

function RCR.GetZoneClassification( zoneId )
	for _, key in ipairs({ "D", "T", "A", "S" }) do
		if (RCR.ZONES[key][zoneId]) then
			return key
		end
	end
	return nil
end

function RCR.GetTexture( name )
	if (not name or name == "") then
		name = "X"
	end
	return string.format("Raidificator/art/%s.dds", name)
end

function RCR.FormatTimestamp( timestamp )
	return os.date("%Y-%m-%d %H:%M", timestamp)
end

function RCR.FormatTime( ms, style )
	-- Styles:
	-- 0 or nil: Long form
	-- 1 Short form, transforms to long at 90 minutes
	-- 2 Short form, transforms to long at 60 minutes
	-- 3 Verbose form with milliseconds

	local rounder = (style == 3) and zo_floor or zo_round
	local s = rounder(ms / 1000)
	local m = s / 60
	local cutoff = (style == 1) and 5400000 or 3600000

	if ((style == 1 or style == 2) and ms < cutoff) then
		return string.format("%d:%02d", zo_floor(m), s % 60)
	elseif (style == 3) then
		return string.format("%d:%02d:%02d.%03d", zo_floor(m / 60), zo_floor(m % 60), s % 60, ms % 1000)
	else
		return string.format("%d:%02d:%02d", zo_floor(m / 60), zo_floor(m % 60), s % 60)
	end
end

function RCR.FormatExtra( ... )
	local _, _, c = ...
	return string.format(c and "%d–%d–%d" or "%d/%d", ...)
end


--------------------------------------------------------------------------------
-- Data Handling
--------------------------------------------------------------------------------

function RCR.GetGroupList( )
	local results = { string.format("~%d:%s", GetSelectedLFGRole(), table.concat(RCR.GetClassSkillLineIds(), ":")) }
	for _, member in pairs(LCCC.GetSortedGroupMembers()) do
		if (IsGroupMemberInSameInstanceAsPlayer(member.unitTag) and not AreUnitsEqual(member.unitTag, "player")) then
			table.insert(results, string.format("%s:%s:%d:%d", member.name, UndecorateDisplayName(member.account), member.class, member.role))
		end
	end
	return table.concat(results, ";")
end

function RCR.UpdateCharacterData( charId, charName, classId )
	RCR.history.chars[charId] = string.format("%s;%s;%d", GetDisplayName(), charName, classId)
end

function RCR.GetCharacterData( character )
	local userId, charName, classId = zo_strsplit(";", character)
	if (not charName) then
		local data = RCR.history.chars[character]
		if (data) then
			userId, charName, classId = zo_strsplit(";", data)
		end
	end
	if (charName) then
		return userId, charName, classId
	else
		return nil
	end
end

function RCR.SaveHistoryItem( key, id, score, duration, extraInfo )
	if (key == "E" and score == 0) then return end

	local contentId = id .. key

	table.insert(RCR.history.clears, table.concat({
		contentId,
		LCCC.GetServerName(),
		GetTimeStamp(),
		GetCurrentCharacterId(),
		score,
		duration,
		table.concat(extraInfo, ";"),
		RCR.GetGroupList(),
	}, ","))
	RCR.UpdateCharacterData(GetCurrentCharacterId(), GetUnitName("player"), GetUnitClassId("player"))
	RCR.NewClearAdded(contentId)
	RCR.RequestDataFlush()
end

function RCR.MigrateData( )
	local oldSV = RaidificatorSavedVariables and RaidificatorSavedVariables.Default
	if (not oldSV) then return end

	if (RCR.vars.migration == 0) then
		for userId, accountData in pairs(oldSV) do
			local history = accountData["$AccountWide"] and accountData["$AccountWide"].history
			for raidId, clears in pairs(history) do
				for _, clear in ipairs(clears) do
					-- Need to manually traverse the group because it may be discontinuous
					local group = { }
					for i = 1, 24 do
						if (clear.groupMembers[i]) then
							table.insert(group, clear.groupMembers[i])
						end
					end

					table.insert(RCR.history.clears, table.concat({
						raidId .. "R",
						"X",
						clear.completed,
						string.format("%s;%s", userId, clear.character),
						clear.score,
						clear.timeInSeconds * 1000,
						string.format("%d;%d", clear.revives, clear.revives + clear.deaths),
						table.concat(group, ";"),
					}, ","))
				end
			end
		end
		RCR.vars.migration = GetTimeStamp()
	elseif (GetTimeStamp() - RCR.vars.migration > 180 * 86400) then
		-- Delete old data after 180 days
		RaidificatorSavedVariables = nil
	end
end

function RCR.GetRaidIdFromContentId( contentId )
	return tonumber(string.match(contentId, "(%d+)R"))
end


--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

function RCR.ToggleEncounterLog( mode )
	local shouldEnable = false
	local currentlyEnabled = IsEncounterLogEnabled()

	if (mode ~= RCR.MODE_INACTIVE) then
		shouldEnable = RCR.vars.autoLog[mode]
	end

	if (shouldEnable and not currentlyEnabled) then
		SetEncounterLogEnabled(true)
		RCR.Msg(GetString(SI_ENCOUNTER_LOG_ENABLED_ALERT))
	elseif (not shouldEnable and currentlyEnabled and RCR.loggingEnabled) then
		SetEncounterLogEnabled(false)
		RCR.Msg(GetString(SI_ENCOUNTER_LOG_DISABLED_ALERT))
	end

	RCR.loggingEnabled = shouldEnable
end

function RCR.InitializeQuestHandler( )
	local name = "RCR_QuestHandler"

	local actions = {
		[1] = { AcceptWorldEventInvite, 0x00CC00, RCR.GetTexture("yes"), true },
		[2] = { DeclineWorldEventInvite, 0xCC0000, RCR.GetTexture("no") },
	}

	local HandleQuestAction = function( eventId, eventName, questName, action )
		if (action) then
			if (action[4] and GetNumJournalQuests() >= MAX_JOURNAL_QUESTS) then
				return RCR.Msg(GetString(SI_ERROR_QUEST_LOG_FULL))
			end
			action[1](eventId)
			RCR.Msg(string.format("|c%06X%s|r%s: %s", action[2], zo_iconFormatInheritColor(action[3], "100%", "100%"), eventName, questName))
		end
	end

	local GetQuestActionCodeForCurrentZone = function( )
		local key = RCR.GetZoneClassification(LCCC.GetZoneId())
		return (key and RCR.vars.quests[key]) or 0
	end

	EVENT_MANAGER:RegisterForEvent(name, EVENT_SCRIPTED_WORLD_EVENT_INVITE, function( eventCode, eventId, scriptedEventName, inviterName, questName )
		HandleQuestAction(eventId, scriptedEventName, questName, actions[GetQuestActionCodeForCurrentZone()])
	end)

	-- Handle event invites that arrived while the player was in a loadscreen
	EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function( eventCode, initial )
		local action = actions[GetQuestActionCodeForCurrentZone()]
		if (action) then
			for i = 1, GetNumScriptedEventInvites() do
				local eventId = GetScriptedEventInviteIdFromIndex(i)
				local isValid, eventName, _, questName = GetScriptedEventInviteInfo(eventId)
				if (isValid) then
					HandleQuestAction(eventId, eventName, questName, action)
				end
			end
		end
	end)
end


--------------------------------------------------------------------------------
-- Subclassing Helpers
--------------------------------------------------------------------------------

function RCR.GetClassSkillLineIds( )
	local results = { }
	for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_CLASS) do
		local _, _, isActive, _, _, _, isClassMastery = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
		if (isActive and not isClassMastery) then
			table.insert(results, GetSkillLineId(SKILL_TYPE_CLASS, skillLineIndex))
		end
	end
	return results
end

function RCR.GetClassSkillLineFormattedName( skillLineId )
	local name = GetSkillLineNameById(skillLineId)
	local icon = select(7, GetClassInfo(GetClassIndexById(GetSkillLineClassId(GetSkillLineIndicesFromSkillLineId(skillLineId)))))
	return ZO_CachedStrFormat(SI_SKILLS_ENTRY_LINE_NAME_CLASS_FORMAT, name, zo_iconFormat(icon, "100%", "100%"))
end


--------------------------------------------------------------------------------
-- Scoring
--------------------------------------------------------------------------------

function RCR.IsTimestampFromSoulReservoirScoringSystem( timestamp )
	return timestamp < 1457341200 -- Update 9 launch
end

function RCR.GetRaidTargetTimeByRaidId( raidId )
	return (GetCurrentParticipatingRaidId() == raidId) and GetRaidTargetTime() or 60000 * (RCR.TARGET_TIMES[raidId] or 0)
end

do	-- See /esoui/ingame/centerscreenannounce/centerscreenannouncehandlers.lua
	local TRIAL_COMPLETE_LIFESPAN_MS = 10000
	function RCR.DisplayScoreBanner( raidId, score, duration, vitality, vitalityMax )
		local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_RAID_COMPLETE_TEXT, SOUNDS.RAID_TRIAL_COMPLETED)
		messageParams:SetEndOfRaidData({ score, ZO_FormatTimeMilliseconds(duration, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_SECONDS), duration < RCR.GetRaidTargetTimeByRaidId(raidId), vitality * 1000, zo_strformat(SI_REVIVE_COUNTER_REVIVES_USED, vitality, vitalityMax) })
		messageParams:SetText(zo_strformat(SI_TRIAL_COMPLETED_LARGE, GetRaidName(raidId)))
		messageParams:SetLifespanMS(TRIAL_COMPLETE_LIFESPAN_MS)
		messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_RAID_TRIAL)
		CENTER_SCREEN_ANNOUNCE:RemoveAllCSAsOfAnnounceType(CENTER_SCREEN_ANNOUNCE_TYPE_RAID_TRIAL)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
	end

	local COUNTDOWN_MS = 4000
	local screenshotScene = nil
	function RCR.DisplayScoreBannerForScreenshot( ... )
		if (not screenshotScene) then
			screenshotScene = ZO_InteractScene:New("RCR_ScoreScreenshot", SCENE_MANAGER, { type = "RCR_ScoreScreenshot", interactTypes = { INTERACTION_NONE } })
			screenshotScene:RegisterCallback("StateChange", function( oldState, newState )
				if (newState == SCENE_SHOWING) then
					KEYBOARD_CHAT_SYSTEM:Minimize()
					KEYBOARD_CHAT_SYSTEM:HideMinBar()
				elseif (newState == SCENE_HIDDEN) then
					KEYBOARD_CHAT_SYSTEM:ShowMinBar()
					KEYBOARD_CHAT_SYSTEM:Maximize()
				end
			end)
		end

		-- Countdown
		SCENE_MANAGER:ShowBaseScene()
		local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_COUNTDOWN_TEXT)
		messageParams:SetLifespanMS(COUNTDOWN_MS)
		messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN)
		CENTER_SCREEN_ANNOUNCE:RemoveAllCSAsOfAnnounceType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
		zo_callLater(function() SCENE_MANAGER:Push("RCR_ScoreScreenshot") end, COUNTDOWN_MS)

		-- Because CSA is queued, the score banner will show only after the countdown has completed
		RCR.DisplayScoreBanner(...)
	end
end

function RCR.RemoveTimeAdjustmentFromScore( raidId, score, duration )
	local targetTime = RCR.GetRaidTargetTimeByRaidId(raidId)
	if (targetTime > 0) then
		local adjustment = zo_max((targetTime - duration) / 10000000 + 1, 0.001)
		return zo_round(score / adjustment / 10) * 10
	end
end


--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

function RCR.RegisterSettingsPanel( )
	local LAM = LCCC.GetLibAddonMenu()

	if (LAM) then
		local panelId = "RaidificatorSettings"

		RCR.settingsPanel = LAM:RegisterAddonPanel(panelId, {
			type = "panel",
			name = RCR.title,
			version = LCCC.FormatVersion(LCCC.GetAddOnVersion(RCR.name)),
			author = "@code65536; original concept by @Olivierko",
			website = RCR.url,
			donation = RCR.url .. "#donate",
		})

		local questActions = { }
		local questActionLabels = { }
		for i = 0, 2 do
			table.insert(questActions, i)
			table.insert(questActionLabels, GetString("SI_RCR_SETTING_QUEST_ACTION", i))
		end

		local castBlockerDescription, castBlockerNotAvailable
		if (RCR.CB) then
			local blockedAbilityNames = { }
			for _, abilityId in ipairs(LCCC.GetSortedKeys(RCR.CB.BLOCKED_IDS)) do
				table.insert(blockedAbilityNames, zo_strformat(SI_ABILITY_TOOLTIP_NAME, GetAbilityName(abilityId)))
			end
			castBlockerDescription = zo_strformat(SI_RCR_SETTING_CASTS_TEXT, ZO_GenerateCommaSeparatedListWithAnd(blockedAbilityNames))
		else
			castBlockerDescription = zo_strformat("<<1>> <<2>>", GetString(SI_ADDON_MANAGER_DEPENDENCIES), zo_strformat(LibCombatAlerts and SI_ADDON_MANAGER_DEPENDENCY_TOO_LOW_VERSION or SI_ADDON_MANAGER_DEPENDENCY_MISSING, "LibCombatAlerts"))
			castBlockerNotAvailable = true
		end

		LAM:RegisterOptionControls(panelId, {
			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_RCR_SECTION_STATUS,
			},
			--------------------
			{
				type = "colorpicker",
				name = SI_RCR_SETTING_BGCOLOR,
				getFunc = function() return LCCC.Int32ToRGBA(RCR.vars.bgColor) end,
				setFunc = function( ... )
					RCR.vars.bgColor = LCCC.RGBAToInt32(...)
					RCR.UpdateStatusBackground()
				end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_RCR_SECTION_LOGGING,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_RCR_SETTING_LOG_DUNGEON,
				getFunc = function() return RCR.vars.autoLog[RCR.MODE_DUNGEON] end,
				setFunc = function(enabled) RCR.vars.autoLog[RCR.MODE_DUNGEON] = enabled end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_RCR_SETTING_LOG_TRIAL,
				getFunc = function() return RCR.vars.autoLog[RCR.MODE_TRIAL] end,
				setFunc = function(enabled) RCR.vars.autoLog[RCR.MODE_TRIAL] = enabled end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_RCR_SETTING_LOG_ENDLESS,
				getFunc = function() return RCR.vars.autoLog[RCR.MODE_ENDLESS] end,
				setFunc = function(enabled) RCR.vars.autoLog[RCR.MODE_ENDLESS] = enabled end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_RCR_SECTION_QUESTS,
			},
			--------------------
			{
				type = "dropdown",
				name = SI_RCR_SETTING_QUESTS_DUNGEONS,
				choices = questActionLabels,
				choicesValues = questActions,
				getFunc = function() return RCR.vars.quests.D end,
				setFunc = function(option) RCR.vars.quests.D = option end,
			},
			--------------------
			{
				type = "dropdown",
				name = SI_RCR_SETTING_QUESTS_TRIALS,
				choices = questActionLabels,
				choicesValues = questActions,
				getFunc = function() return RCR.vars.quests.T end,
				setFunc = function(option) RCR.vars.quests.T = option end,
			},
			--------------------
			{
				type = "dropdown",
				name = SI_RCR_SETTING_QUESTS_ARENAS,
				choices = questActionLabels,
				choicesValues = questActions,
				getFunc = function() return RCR.vars.quests.A end,
				setFunc = function(option) RCR.vars.quests.A = option end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_RCR_SECTION_CASTS,
			},
			--------------------
			{
				type = "description",
				text = castBlockerDescription,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_ADDON_MANAGER_ENABLED,
				getFunc = function() return RCR.vars.castBlocker end,
				setFunc = function( enabled )
					RCR.vars.castBlocker = enabled
					RCR.CB.RefreshEnablementState()
				end,
				disabled = castBlockerNotAvailable,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_RCR_DTR_TITLE,
			},
			--------------------
			{
				type = "description",
				text = SI_RCR_DTR_DISCOVERY,
			},
		})
	end
end

function RCR.CheckObsolete( )
	local DTR = DungeonTrialReset
	if (type(DTR) == "table" and type(DTR.version) == "number") then
		RCR.Msg(zo_strformat(SI_RCR_MESSAGE_OBSOLETE, "Dungeon and Trial Instance Reset Tool"))
	end

	local DT = DungeonTimer
	if (type(DT) == "table" and type(DT.name) == "string") then
		RCR.Msg(zo_strformat(SI_RCR_MESSAGE_OBSOLETE, "Dungeon Timer"))
		EVENT_MANAGER:UnregisterForEvent(DT.name, EVENT_PLAYER_ACTIVATED)
	end
end

EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
