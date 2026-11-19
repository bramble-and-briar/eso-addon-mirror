-- Copyright (c) 2025 by Tagarn

-- This add-on may be copied, shared, and used as-is while playing Elder
-- Scrolls Online, provided this notice is left intact. However, this
-- add-on, in part or in full, may not be used in the creation of other
-- add-ons without the express written consent of Tagarn.

-- The Elder Scrolls Online add-on provided by Tagarn ("we," "us," or "our")
-- is for entertainment purposes only. UNDER NO CIRCUMSTANCE SHALL WE HAVE ANY
-- LIABILITY TO YOU FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF
-- THE USE OF OUR ADD-ON. YOUR USE OF OUR ADD-ON IS SOLELY AT YOUR OWN RISK.

SkillPointAlerts = SkillPointAlerts or {}
local SPA = SkillPointAlerts
local WM = WINDOW_MANAGER

local EM = EVENT_MANAGER

local SM = SCENE_MANAGER
local LAM = LibAddonMenu2
local SFL = SkillPointAlerts.SortFilterList
local SV = {} -- set to SPA.SavedVariables after saved variables are opened in Initialize()

local task = SPA.task or LibAsync:Create("SPA_worker")
SPA.task = task

SPA.name = "SkillPointAlerts"
SPA.simpleName = GetString(SPA_APP_NAME)
SPA.displayName = GetString(SPA_APP_NAME_LONG)
SPA.author = GetString(SPA_TAGARN_GREEN)
SPA.version = "1.30"
SPA.versionNumeric = 130 -- for checking whether to show the "new feature" dialog or not
SPA.buildNumber = 1 -- for when the testing version box is showing

SPA.debugOptions = false -- DEBUG switch to false before release
SPA.debugNoTargets = false -- DEBUG for simulating no targets
SPA.debugAllowDlcLocked = false -- DEBUG allow DLC locked content to be targets. For testing some features with a DLC-locked account

SPA.dataForLater = {} -- DEBUG For saving output from code that can't output to chat, such as Initialize()

SPA.zoneId = nil -- rather than looking it up many times, just fetch it once per zone
SPA.checkCallLater = nil -- Reference to the zo_callLater used by the main Check() function
SPA.reloaded = false -- For tracking if we just initialized or not, for things such as outputting my big "RELOAD" message to chat
SPA.isInitializing = true -- Flag whether initializing still, as the zo_callLater() for Check() might run before the delayed player activated
SPA.mainPanelFragment = nil -- the panelFragment for the UI
SPA.excludedZoneIds = nil -- the zones this add-on will be disabled for
SPA.isExcludedZone = false -- flags if we determined the UI should be disabled in this zone
SPA.lastZoneWasExcluded = false -- flags if the last zone was an excluded zone, and we should bring back the UI
SPA.delveTarget = nil -- the currently selected delve target
SPA.dungeonTarget = nil -- the currently selected dungeon target
SPA.overallTarget = nil -- the currently selected overall target, by ranking points
SPA.currentJumpTarget = nil -- the current target, when the mouseover event happened
SPA.jumpData = nil -- the data for the target being jumped to (must stay separate from SPA.currentJumpTarget)
SPA.previousTargetCount = 0 -- for tracking how many targets were seen in the last Check() pass
SPA.isCharacterComplete = false -- whether the character has all the skyshards and events completed
SPA.currentTooltipControl = nil -- pointer to the button with the current tooltip, or nil
SPA.currentTooltipIsDelve = nil -- what type of target the current tooltip is for
SPA.checkIsRunning = false -- Flags that an instance of SPA.Check() is running in LibAsync, so don't start another
SPA.wasUiOpenedByHotkey = false -- Flags if the main UI was opened by hotkey, and so it shouldn't auto hide if empty
SPA.wasUiManuallyHidden = false -- Flags if the main UI was manually hidden by hotkey or close
SPA.wasUiHiddenByCombat = false -- Flags if the UI is hidden due to combat, so it can be restored when combat ends
SPA.wasInfoOpenedByHotkey = false -- Flags if the Info window was opened by hotkey, and so it shouldn't close when the main UI is closed by hotkey
SPA.currentMapShowing = 0 -- For tracking which map is visible, if we opened it, for panning. 0 is no map
SPA.currentMapZoneId = 0 -- The zoneId for what is being pointed to on the map
SPA.inTargetZone = false -- Flags if the current zone has a target
SPA.questNamesList = nil -- As the EVENT_QUEST_COMPLETE event does not pass the questId, a comparison by name is needed
SPA.zoneIdOfQuestDialogShown = 0 -- the zoneId when the last quest dialog was shown, to ensure we don't show it again this load (unless the player goes to the other quest dungeon and returns)
SPA.targetZoneStatus = {} -- Contains data on what is available in the current target zone 
SPA.delvesList = nil
SPA.dungeonsList = nil
SPA.groupDelvesList = {} -- A list of group delves for quick checks


-- The alpha settings for when the smaller icons are available or not (they are hidden when complete)
SPA.alphaMax = 1.0
SPA.alphaFaded = 0.2

SPA.mainPositionDefault = {["x"]=344, ["y"]=6} -- The default main UI position

SPA.savedVariables = nil -- The saved variables. The shortcut SV is assigned in Initialize(), after the saved variables are loaded
-- Defaults for the saved variables
local saveDefaults = {
	mainPosition = {},  -- position of the main UI, saved by the screen resolution
	infoPosition = {},  -- position of the Info UI, saved by the screen resolution
	uiHideInCombat = true, -- if the UI should hide when combat starts
    uiShowOnNewTarget = true, -- if main UI is hidden, whether to show when a target is available
    uiShowFirstTargetOnly = true, -- if main UI is hidden, whether to show it when it goes from empty to not empt
    uiHideEmpty = false, -- whether to hide the UI when no targets are available
    infoStatsIncludeLocked = false, -- whether to count locked content for Info stats
	infoListsIncludeLocked = true, -- whether to show locked content in Info list
    notificationSounds = true, -- whether to play notification sounds
    notificationFirstOnly = true, -- whether to only play sound when targets go from zero to one
    notificationWhenUiIsHidden = false, -- whether to play sound if UI is hidden
	friendPriority = false, -- whether to prioritize porting to friends
	groupPriority = true, -- whether to prioritize porting to group members
	guildPriority = false, -- whether to prioritize porting to guild members
	mapZoomToTarget = true, -- whether to pan/zoom the map to the target
	mapCreateWaypoint = false, -- whether to create a map destination (waypoint) at the delve/dungeon location
	versionLastRun = SPA.versionNumeric, -- prevent new users from seeing the "new features" dialog

	-- Counters for various usage tracking
    delveSkyshardCount = 0,
    pdSkyshardCount = 0,
    pdGroupEventCount = 0,
    pdQuestCount = 0,
    delvePortsCount = 0,
    pdPortsCount = 0,
    portedToTagCount = 0,
	firstPortToTag = nil,

	-- Other notifications
	groupDelveNotification = false, -- whether the Group Delve pop-up has been shown
}


-- For easily controlling debug output
local function dbg(...)
	if (SPA.debugOptions == true) then
		--FIXME: Replace the deprecated unpack
---@diagnostic disable-next-line: deprecated
		df(unpack({...}))
	end
end


function SPA.Test()
    dbg("API version: %s", tostring(GetAPIVersion()))

    local zoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy
    local zoneName = GetPlayerActiveZoneName()

    dbg("%s, %d: isExcludedZone: %s", zoneName, zoneId, tostring(SPA.isExcludedZone))

	-- SPA.ListCurrentZoneSkyshards()

	-- -- df("%s  %s", tostring(IsPlayerInGroup(GetUnitDisplayName("player"))), tostring(MAX_GROUP_SIZE_THRESHOLD))

	-- SPA.ShowZoneHighlightedAchievements()

	-- SPA.ShowPlayerNormalizedLocation()

	-- SPA.ShowAchievementInfo(4471)
end

function SPA.Stats()
    d(GetString(SPA_STATS_TITLE))

    d(GetString(SPA_STATS_TITLE_DELVE))
	d(zo_strformat(SPA_STATS_PORTS_DELVE, SPA.savedVariables.delvePortsCount))
	d(zo_strformat(SPA_STATS_SKYSHARDS_DELVE, SPA.savedVariables.delveSkyshardCount))
	
    d(GetString(SPA_STATS_TITLE_DUNGEON))
	d(zo_strformat(SPA_STATS_PORTS_DUNGEON, SPA.savedVariables.pdPortsCount))
	d(zo_strformat(SPA_STATS_SKYSHARDS_DUNGEON, SPA.savedVariables.pdSkyshardCount))
	d(zo_strformat(SPA_STATS_GROUP_EVENTS, SPA.savedVariables.pdGroupEventCount))
	d(zo_strformat(SPA_STATS_QUESTS, SPA.savedVariables.pdQuestCount))
end

-- Counting needed delves and public dungeons for the Info window
-- Return: a table containing the data objects for the needed delves/dungeons
function SPA.CountNeeded()
    local delveSkyshardsNeededCount = 0
    local pdNeededCount = 0
    local pdSkyshardsNeededCount = 0
    local pdEventsNeededCount = 0
    local pdQuestsNeededCount = 0
    local delvesCount = 0
    local pdsCount = 0

    local zoneData = {}

    -- count what's needed for the Info window, and put needed zone data into a list for sorting
    for x, data in pairs(SPA.data) do
        local skyshardNeeded = (GetSkyshardDiscoveryStatus(data.skyshardId) ~= SKYSHARD_DISCOVERY_STATUS_ACQUIRED)
        if (data.isDelve == true) then
            delvesCount = delvesCount + 1
            if (skyshardNeeded == true) then
                table.insert(zoneData, data)
                delveSkyshardsNeededCount = delveSkyshardsNeededCount + 1
            end
        else
            local _, _, _, _, groupEventStatus, _, _ = GetAchievementInfo(data.groupEventId)
            local groupEventNeeded = not groupEventStatus
            local questNeeded = nil
            if (data.questId ~= nil) then
                questNeeded = not HasCompletedQuest(data.questId)
            end

            pdsCount = pdsCount + 1
            if (groupEventNeeded == true) or (skyshardNeeded == true) or (questNeeded == true) then
                table.insert(zoneData, data)
                pdNeededCount = pdNeededCount + 1
            end

            if (skyshardNeeded == true) then
                pdSkyshardsNeededCount = pdSkyshardsNeededCount + 1
            end

            if (groupEventNeeded == true) then
                pdEventsNeededCount = pdEventsNeededCount + 1
            end

            if (questNeeded == true) then
                pdQuestsNeededCount = pdQuestsNeededCount + 1
            end
        end -- if (data.isDelve == true) then
    end -- for x, data in pairs(SPA.data) do

    return delveSkyshardsNeededCount, pdNeededCount, pdSkyshardsNeededCount, pdEventsNeededCount, pdQuestsNeededCount,
           delvesCount, pdsCount, zoneData
end

-- A general one-button dialog box
function SPA.ShowDialog(uniqueId, title, body, buttonText)
	if (buttonText == nil) then
		buttonText = SI_DIALOG_CLOSE
	end

    ESO_Dialogs[uniqueId] = {
        canQueue = true,
        uniqueIdentifier = uniqueId,
        title = {
            text = title
        },
        mainText = {
            text = body
        },
        buttons = {
            [1] = {
                text = buttonText,
                callback = function(dialog)
                end
            }
        },
        setup = function(dialog, data)
        end
    }	

	ZO_Dialogs_ShowDialog(uniqueId)

end

-- Show the Craglorn Group Delve info dialog
function SPA.ShowCraglornGroupDelveDialog()
    local title = GetString(SPA_DIALOG_CRAGLORN_GROUP_DELVES_TITLE)
    local body = GetString(SPA_DIALOG_CRAGLORN_GROUP_DELVES_BODY)

	SPA.ShowDialog("SPA_CRAGLORN_DIALOG", title, body)
    d(GetString(SPA_ABBREV_RED) .. " " .. body) -- output the message to chat
	SV.groupDelveNotification = true
end


-- Show the High Isle public dungeon quest reminder dialog
function SPA.ShowQuestDialog(questName, questGiver)
    local title = GetString(SPA_DIALOG_QUEST_TITLE)
    local body = zo_strformat(SPA_DIALOG_QUEST_BODY, questName, questGiver)

	SPA.ShowDialog("SPA_QUEST_DIALOG", title, body)
    d(GetString(SPA_ABBREV_RED) .. " " .. body) -- output the message to chat
end

-- Show the Easter Egg dialog :)
function SPA.ShowTagDialog()
    local title = GetString(SPA_DIALOG_TAG_TITLE)

    local totalPorts = SPA.savedVariables.delvePortsCount + SPA.savedVariables.pdPortsCount
    local totalSkillPoints = ((SPA.savedVariables.delveSkyshardCount + SPA.savedVariables.pdSkyshardCount) / 3) +
                                 SPA.savedVariables.pdGroupEventCount + SPA.savedVariables.pdQuestCount
    local totalSkillPointsString = string.format("%.0f", totalSkillPoints)

    local body = zo_strformat(SPA_DIALOG_TAG_BODY, totalPorts, totalSkillPointsString)

	SPA.ShowDialog("SPA_TAG_DIALOG", title, body)
end

-- Show the New Feature dialog
function SPA.ShowNewFeatureDialog()
    local title = GetString(SPA_DIALOG_NEW_FEATURE_TITLE)
	local body = GetString(SPA_DIALOG_NEW_FEATURE_BODY)
	SPA.ShowDialog("SPA_NEW_FEATURE_DIALOG", title, body)
end

function SPA.IsZoneADelve(zoneId)
    if (SPA.data[zoneId] ~= nil) then
        return SPA.data[zoneId].isDelve
    end

    return nil
end

-- For setting up the "This zone:" main UI box, as appropriate
function SPA.ConfigureThisZone()
    local skyshardNeeded = false
    local groupEventNeeded = false
    local questNeeded = false
    local zoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy
    local data = SPA.data[zoneId]

    if (data == nil) then
        SPAUI_CurrentZone:SetHidden(true)
        SPAUI_CurrentZone_Skyshard:SetHidden(true)
        SPAUI_CurrentZone_GroupEvent:SetHidden(true)
        SPAUI_CurrentZone_Quest:SetHidden(true)
        SPA.inTargetZone = false
        return
    end

    if (GetSkyshardDiscoveryStatus(data.skyshardId) ~= SKYSHARD_DISCOVERY_STATUS_ACQUIRED) then
        skyshardNeeded = true
    end

    if (data.isDelve == false) then
        local _, _, _, _, groupEventStatus, _, _ = GetAchievementInfo(data.groupEventId)
        groupEventNeeded = not groupEventStatus

        if (data.questId ~= nil) then
            questNeeded = not HasCompletedQuest(data.questId)
        end
    end

    SPAUI_CurrentZone_Skyshard:SetHidden(not skyshardNeeded)
    SPAUI_CurrentZone_GroupEvent:SetHidden(not groupEventNeeded)
    SPAUI_CurrentZone_Quest:SetHidden(not questNeeded)

    if ((skyshardNeeded == true) or (groupEventNeeded == true) or (questNeeded == true)) then
        SPAUI_CurrentZone:SetHidden(false)
        SPA.inTargetZone = true
    else
        SPAUI_CurrentZone:SetHidden(true)
        SPA.inTargetZone = false
        return
    end

    local questName = ""

    if (questNeeded == true) then
        questName = GetQuestName(data.questId)
    end

    -- Determine if the Public Dungeon Quest Available dialog should be shown
    if (questNeeded == true) then
        local hasQuest = HasQuest(data.questId)

        if (hasQuest == false) and (SPA.zoneIdOfQuestDialogShown ~= SPA.zoneId) then
			SPA.zoneIdOfQuestDialogShown = SPA.zoneId
			SPA.ShowQuestDialog(GetQuestName(data.questId), data.questGiver)
        end
    end

    SPA.targetZoneStatus = {}
    SPA.targetZoneStatus.zoneId = zoneId
    SPA.targetZoneStatus.skyshardNeeded = skyshardNeeded
    SPA.targetZoneStatus.groupEventNeeded = groupEventNeeded
    SPA.targetZoneStatus.questNeeded = questNeeded
    SPA.targetZoneStatus.questName = questName
end

-- For doing the actual travel
function SPA.Jump(isDelve)
	local target = nil

	if (isDelve == nil) then -- here nil means the overall target (called from hotkey)
		target = SPA.overallTarget
	elseif (isDelve == true) then
		target = SPA.delveTarget
	else 
		target = SPA.dungeonTarget
	end

	if (target == nil) then
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, SPA_ERROR_NO_TARGET_AVAILABLE)
		return
	end

	--LATER: does this still happen?
    if (target.displayName == "") then
		if (SPA.debugOptions == true) then
			dbg("************** (target.displayName == \"\") in SPA.Jump()")
		end
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, SPA_ERROR_NO_TARGET_AVAILABLE)
        return
    end

    d(zo_strformat(SPA_JUMP_MESSAGE, target.displayName, target.zoneName, target.parentZoneName))

	-- Ensure the current target is saved, for counting ports after reload
	SPA.jumpData = SPA.U.DeepCopy(target)

    if (target.fromFriendsList == true) then
        JumpToFriend(target.displayName)
    else
        JumpToGuildMember(target.displayName)
    end
end

--LATER: ideally, contain all these and next three methods into a subclass
local delveTarget = nil
local dungeonTarget = nil
local overallTarget = nil

-- Used by the main Check() loop, this creates the data object for a potential teleport
function SPA.ProcessPlayer(displayName, zoneName, zoneId, isFromFriendsList, data, index, guildId)
    local dInfo = {}
    local skyshardNeeded = false
    local groupEventNeeded = false
    local questNeeded = nil
	local rankingPoints = 0

	-- weights used for ranking

	local PRIORITY = 8
	local SKYSHARD = 2
	local GROUP_EVENT = 4
	local QUEST = 1


    if (GetSkyshardDiscoveryStatus(data.skyshardId) ~= SKYSHARD_DISCOVERY_STATUS_ACQUIRED) then
        skyshardNeeded = true
    end

    if (data.isDelve == false) then
        local _, _, _, _, groupEventStatus, _, _ = GetAchievementInfo(data.groupEventId)
        groupEventNeeded = not groupEventStatus

        if (data.questId ~= nil) then
            questNeeded = not HasCompletedQuest(data.questId)
        end
    end

	if ( (skyshardNeeded == false) and (groupEventNeeded ~= true ) and (questNeeded ~= true) ) then
		return nil
	end

	if (skyshardNeeded == true) then
		rankingPoints = rankingPoints + SKYSHARD
	end
	if (groupEventNeeded == true) then
		rankingPoints = rankingPoints + GROUP_EVENT
	end
	if (questNeeded == true) then
		rankingPoints = rankingPoints + QUEST
	end
	if (SV.friendPriority == true) and (isFromFriendsList == true) then
		rankingPoints = rankingPoints + PRIORITY
	end
	
	if (SV.groupPriority == true) and (guildId == nil) then
		rankingPoints = rankingPoints + PRIORITY
	end

	if (SV.guildPriority == true) and (guildId ~= nil) then
		rankingPoints = rankingPoints + PRIORITY
	end

    local inGroup = IsPlayerInGroup(displayName)

	dInfo.displayName = displayName
    dInfo.fromFriendsList = isFromFriendsList
    dInfo.isGrouped = inGroup
    dInfo.zoneName = zoneName
    dInfo.zoneId = zoneId
    dInfo.parentZoneName = data.parentZoneName
    dInfo.isDelve = data.isDelve
    dInfo.skyshardNeeded = skyshardNeeded
    dInfo.groupEventNeeded = groupEventNeeded
    dInfo.questNeeded = questNeeded
    dInfo.rankingPoints = rankingPoints

	if (guildId == nil) then
		dInfo.friendIndex = nil
		dInfo.memberIndex = nil
		dInfo.guildId = nil
	else
		if (isFromFriendsList == true) then
			dInfo.friendIndex = index
		else
			dInfo.memberIndex = index
			dInfo.guildId = guildId
		end	
	end

    return dInfo
end

-- Does the work of determining the latest player data's rank
function SPA.ProcessPlayerData(isFromFriendsList, displayName, playerStatus, zoneId, zoneName, index, guildId)
	local isDelve = nil
	local comparator = nil

	

	if (SPA.data[zoneId] ~= nil) and (zoneId ~= SPA.zoneId) and (SPA.debugAllowDlcLocked == true or CanJumpToPlayerInZone(zoneId))  then
		local data = SPA.ProcessPlayer(displayName, zoneName, zoneId, isFromFriendsList, SPA.data[zoneId], index, guildId)
		if (data == nil) then
			return nil
		end
	
		if (SPA.data[zoneId].isDelve == true) then
			isDelve = true
			comparator = delveTarget
		else
			isDelve = false
			comparator = dungeonTarget
		end

		if (comparator == nil) then
			comparator = data
		else
			if (data.rankingPoints > comparator.rankingPoints) then
				comparator = data
			end
		end

		if (overallTarget == nil) then
			overallTarget = data
		elseif (data.rankingPoints > overallTarget.rankingPoints) then
			overallTarget = data
		end

		if (isDelve == true) then
			delveTarget = comparator
		else
			dungeonTarget = comparator
		end

	end -- if (SPA.data[zoneId] ~= nil) and (zoneId ~= currentZoneId) and (CanJumpToPlayerInZone(zoneId)) then

	return isDelve
end

-- The main loop of this add-on. It processes the friends and guildies lists, looking for players
-- that are in a delve/dungeon with a needed skyshard or group event
function SPA.Check()
    -- Ensure that Check does not have more than one instance running, and that
	-- we aren't still initializing
    if (SPA.checkIsRunning == true) or (SPA.isInitializing == true) then
        return
    end

	-- Don't run the scanning if we're in an excluded zone
    if (SPA.isExcludedZone == true) then
		-- Potentially a zo_callLater is still running when we zone, so ensure it stops
        if (SPA.checkCallLater ~= nil) then
            zo_removeCallLater(SPA.checkCallLater)
            SPA.checkCallLater = nil
        end

        return
	end

    SPA.checkIsRunning = true -- flag that an instance of Check() is running
    SPA.checkCallLater = nil -- clear the zo_callLater() variable

	local delveTargetCount = 0 -- count of delve targets found
	local dungeonTargetCount = 0 -- count of dungeon targets found

	-- clear the local version of the targets (add-on wide version is copied at near the end)
	delveTarget = nil
	dungeonTarget = nil
	overallTarget = nil

    local currentZoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy


	-- Process group
	if (IsPlayerInGroup(GetUnitDisplayName("player")) == true) then
		for i = 1, MAX_GROUP_SIZE_THRESHOLD do
			local unitId = "group" .. i
			if (DoesUnitExist("group" .. i) == true) and (GetUnitDisplayName("player") ~= GetUnitDisplayName(unitId)) then
				local zoneId = GetZoneId(GetUnitZoneIndex(unitId) or 0)
				if (SPA.data[zoneId] ~= nil) and (SPA.data[zoneId].noWayshrine ~= true) then
					local zoneName = GetZoneNameById(zoneId)
					local displayName = GetUnitDisplayName(unitId)
					local playerStatus = PLAYER_STATUS_ONLINE
					if (IsUnitOnline(unitId) == false) then
						playerStatus = PLAYER_STATUS_OFFLINE
					end
					local isDelve = SPA.ProcessPlayerData(true, displayName, playerStatus, zoneId, zoneName, nil)
					if (isDelve ~= nil) then
						if (isDelve == true) then
							delveTargetCount = delveTargetCount + 1
						else
							dungeonTargetCount = dungeonTargetCount + 1
						end
					end					
				end
			end
		end

		
	end

    -- Process the friends list
    local numFriends = GetNumFriends()
	if (SPA.debugNoTargets == true) then
		numFriends = 0
	end
    SPA.task:For(1, numFriends):Do(function(friendIndex)
        local displayName, _, playerStatus, _ = GetFriendInfo(friendIndex)

        if (playerStatus ~= PLAYER_STATUS_OFFLINE) then
            local _, _, zoneName, _, _, _, _, zoneId, _ = GetFriendCharacterInfo(friendIndex)
			--LATER: Could check that zoneId ~= SPA.zoneId here
			if (SPA.data[zoneId] ~= nil) and (SPA.data[zoneId].noWayshrine ~= true) and (SPA.data[zoneId].groupDelve ~= true) then
				local isDelve = SPA.ProcessPlayerData(true, displayName, playerStatus, zoneId, zoneName, friendIndex)
				if (isDelve ~= nil) then
					if (isDelve == true) then
						delveTargetCount = delveTargetCount + 1
					else
						dungeonTargetCount = dungeonTargetCount + 1
					end
				end
			end
        end 
    end) -- SPA.task:For(1, numFriends):Do(function(friendIndex)

    -- Process the guild list(s)
    :Then(function()
        -- LATER: Perhaps this LibAsync:For() is redundant, since the loop immediately following also uses LibAsync()
        local numGuilds = GetNumGuilds()
		if (SPA.debugNoTargets == true) then
			numGuilds = 0
		end
        SPA.task:For(1, numGuilds):Do(function(guildIndex)
            local guildiesOnline = 0
            local guildId = GetGuildId(guildIndex)
            local playerMemberIndex = GetPlayerGuildMemberIndex(guildId)
            local guildMemberCount = GetNumGuildMembers(guildId)
            local currentZoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy

            SPA.task:For(1, guildMemberCount):Do(function(memberIndex)
                local displayName, _, _, playerStatus, _ = GetGuildMemberInfo(guildId, memberIndex)

				if (playerStatus ~= PLAYER_STATUS_OFFLINE) and (displayName ~= GetUnitDisplayName("player")) then
                    local _, _, zoneName, _, _, _, _, zoneId, _ = GetGuildMemberCharacterInfo(guildId, memberIndex)
					-- check if it's a zone we might want
					if (SPA.data[zoneId] ~= nil) and (SPA.data[zoneId].noWayshrine ~= true) and (SPA.data[zoneId].groupDelve ~= true) then
						local isDelve = SPA.ProcessPlayerData(false, displayName, playerStatus, zoneId, zoneName, memberIndex, guildId)
						if (isDelve ~= nil) then
							if (isDelve == true) then
								delveTargetCount = delveTargetCount + 1
							else
								dungeonTargetCount = dungeonTargetCount + 1
							end
						end
					end

                end 
            end) 
        end) -- SPA.task:For(1, numGuilds):Do(function(guildIndex)
	end) -- :Then(function() 

	-- Check if the tooltip needs to change
	:Then(function()
		if (SPA.currentTooltipControl ~= nil) and (SPA.currentJumpTarget ~= nil) then

			-- check if a new target
			local compare = nil
			local previousJumpTargetType = SPA.currentJumpTarget.isDelve
			local previousTooltipControl = SPA.currentTooltipControl

			if (SPA.currentJumpTarget.isDelve == true) then
				compare = delveTarget
			else
				compare = dungeonTarget
			end

			if (compare == nil) or (SPA.currentJumpTarget.displayName ~= compare.displayName) then
				SPA.HideTooltipText()
				SPA.currentJumpTarget = nil
			else
				-- check if jump target moved
				local zoneId = 0
				if (SPA.currentJumpTarget.isFromFriendsList == true) then
					local _, _, _, _, _, _, _, zoneId1, _ = GetFriendCharacterInfo(SPA.currentJumpTarget.friendIndex)
					zoneId = zoneId1
				else
					local _, _, _, _, _, _, _, zoneId1, _ = GetGuildMemberCharacterInfo(SPA.currentJumpTarget.guildId, SPA.currentJumpTarget.memberIndex)
					zoneId = zoneId1
				end

				if (zoneId ~= nil) and (SPA.currentJumpTarget.zoneId ~= zoneId) then
					SPA.HideTooltipText()
					SPA.currentJumpTarget = nil
				end
			end

			-- create new tooltip, if needed
			if (SPA.currentJumpTarget == nil) then
				-- set new target
				if (previousJumpTargetType == true) then
					SPA.CreateTooltipText(previousTooltipControl, delveTarget)
					SPA.delveTarget = SPA.U.DeepCopy(delveTarget)
				else
					SPA.CreateTooltipText(previousTooltipControl, dungeonTarget)
					SPA.dungeonTarget = SPA.U.DeepCopy(dungeonTarget)
				end
			end
		end -- if (SPA.currentTooltipButton ~= nil) then
	end) -- :Then(function()

	-- Set the main UI icons as appropriate
    :Then(function()
		local targetCount = delveTargetCount + dungeonTargetCount
        -- delve icon
        if (delveTarget == nil) then
			if (SPAUI_Delve:GetState() ~= BSTATE_DISABLED) then
            	SPAUI_Delve:SetEnabled(false)
			end
            SPAUI_Delve_Skyshard:SetEnabled(false)
            SPAUI_Delve_Skyshard:SetAlpha(SPA.alphaFaded)
        else
			if (SPAUI_Delve:GetState() == BSTATE_DISABLED) then
            	SPAUI_Delve:SetEnabled(true)
			end
            SPAUI_Delve_Skyshard:SetEnabled(true)
            SPAUI_Delve_Skyshard:SetAlpha(SPA.alphaMax)
        end

        -- public dungeon icon
		if (dungeonTarget == nil) then
			if (SPAUI_Dungeon:GetState() ~= BSTATE_DISABLED) then
           		SPAUI_Dungeon:SetEnabled(false)
			end
            SPAUI_Dungeon_Event:SetAlpha(SPA.alphaFaded)
            SPAUI_Dungeon_Skyshard:SetAlpha(SPA.alphaFaded)
            SPAUI_Dungeon_Quest:SetAlpha(SPA.alphaFaded)
        else
			if (SPAUI_Dungeon:GetState() == BSTATE_DISABLED) then
				SPAUI_Dungeon:SetEnabled(true)
			end
            if (dungeonTarget.skyshardNeeded  == true) then
                SPAUI_Dungeon_Skyshard:SetAlpha(SPA.alphaMax)
			else
                SPAUI_Dungeon_Skyshard:SetAlpha(SPA.alphaFaded)
            end
            if (dungeonTarget.groupEventNeeded == true) then
                SPAUI_Dungeon_Event:SetAlpha(SPA.alphaMax)
			else
                SPAUI_Dungeon_Event:SetAlpha(SPA.alphaFaded)
            end

            if (dungeonTarget.questNeeded ~= true) then -- dungeon doesn't have a quest, so hide the icon
                SPAUI_Dungeon_Quest:SetAlpha(SPA.alphaFaded)
            else
				SPAUI_Dungeon_Quest:SetAlpha(SPA.alphaMax)
            end
        end

        -- show hidden UI, if appropriate
        if (targetCount > SPA.previousTargetCount) then
            if (SPA.IsUiHidden() == true) then
                if (SPA.savedVariables.uiShowOnNewTarget == true) then
                    if ((SPA.savedVariables.uiShowFirstTargetOnly == false) or (SPA.previousTargetCount == 0)) then
						SPA.ShowUi(true)
                    end
                end
            end
        end

		-- show hidden UI if hide option is off
		-- df("(SPAUI:IsHidden() == true)  %s", tostring((SPAUI:IsHidden() == true) ))
		-- df("(SPA.uiHideEmpty == false) %s", tostring((SV.uiHideEmpty == false)))
		-- df("(SPA.wasUiManuallyHidden == false) %s", tostring((SPA.wasUiManuallyHidden == false)))
		-- df("(IsUnitInCombat(\"player\") == false) %s", tostring((IsUnitInCombat("player") == false)))

		if (SPA.IsUiHidden() == true) and (SV.uiHideEmpty == false) and (SPA.wasUiManuallyHidden == false) and (IsUnitInCombat("player") == false) then
			SPA.ShowUi(true)
		end

		-- show UI if in a target zone
		if (SPA.IsUiHidden() == true) and (SPA.inTargetZone == true) and (SPA.wasUiManuallyHidden == false) then
			SPA.ShowUi(true)
		end

		-- show UI if the previous zone was an excluded zone
		if (SPA.IsUiHidden() == true) and (SPA.lastZoneWasExcluded == true) and (SPA.wasUiManuallyHidden == false) then
			SPA.ShowUi(true)
		end		
		SPA.lastZoneWasExcluded = false

		-- show UI if there are targets and the UI wasn't manually hidden
		if (SPA.IsUiHidden() == true) and (targetCount > 0) and (SPA.wasUiManuallyHidden == false) then
			SPA.ShowUi(true)
		end

        -- notification sound, if appropriate
        if (targetCount > SPA.previousTargetCount) then
            if (SPA.savedVariables.notificationSounds == true) then
                if ((SPA.savedVariables.notificationFirstOnly == false) or (SPA.previousTargetCount == 0)) then
                    if ((SPA.IsUiHidden() == false) or (SPA.savedVariables.notificationWhenUiIsHidden == true)) then
                        PlaySound(SPA.notificationSound)
                        PlaySound(SPA.notificationSound)
                        PlaySound(SPA.notificationSound)
                    end
                end
            end
        end

        -- hide UI if empty, if appropriate
        if ( (SPA.IsUiHidden() == false) and (targetCount == 0) and (SPA.inTargetZone == false) and (SPA.wasUiOpenedByHotkey == false) and (SPA.savedVariables.uiHideEmpty == true)) then
			SPA.ShowUi(false)
        end

        SPA.previousTargetCount = targetCount -- store the new targets count for next time

		-- copy the newly selected targets to the main add-on variables, or null out the main add-on variables, as appropriate
		if (delveTarget == nil) then
			SPA.delveTarget = nil
		elseif ( SPA.delveTarget == nil ) or ( (SPA.delveTarget ~= nil) and (delveTarget.zoneId ~= SPA.delveTarget.zoneId) )then
				SPA.delveTarget = SPA.U.DeepCopy(delveTarget)
		end
		if (dungeonTarget == nil) then
			SPA.dungeonTarget = nil
		elseif ( SPA.dungeonTarget == nil ) or ( ( SPA.dungeonTarget ~= nil ) and (dungeonTarget.zoneId ~= SPA.dungeonTarget.zoneId) ) then
			SPA.dungeonTarget = SPA.U.DeepCopy(dungeonTarget)
		end
		if (overallTarget == nil) then
			SPA.overallTarget = nil
		elseif ( SPA.overallTarget == nil ) or ( ( SPA.overallTarget ~= nil ) and (overallTarget.zoneId ~= SPA.overallTarget.zoneId) ) then
			SPA.overallTarget = SPA.U.DeepCopy(overallTarget)
		end

        -- run Check() again
        SPA.checkCallLater = zo_callLater(function(self)
            SPA.Check()
        end, 1000)

        -- flag that an instance of Check() is no longer running
        SPA.checkIsRunning = false
    end) -- :Then(function()
end

-- Generate the lists used by the Info window
function SPA.CreateInfoLists()
    local delvesList = {}
    local dungeonsList = {}
    local lockedNeededDelves = 0
    local lockedNeededDungeons = 0
    local lockedDelvesTotal = 0
    local lockedDungeonsTotal = 0

    for k, data in pairs(SPA.data) do
        local skyshardNeeded = false
        local groupEventNeeded = false
        local questNeeded = false

		local isLocked = not CanJumpToPlayerInZone(data.zoneId)

        if (isLocked == true) then
            if (data.isDelve == true) then
                lockedDelvesTotal = lockedDelvesTotal + 1
            else
                lockedDungeonsTotal = lockedDungeonsTotal + 1
            end
        end

        if (GetSkyshardDiscoveryStatus(data.skyshardId) ~= SKYSHARD_DISCOVERY_STATUS_ACQUIRED) then
            skyshardNeeded = true
        end
        if (data.isDelve == false) then
            local _, _, _, _, groupEventStatus, _, _ = GetAchievementInfo(data.groupEventId)
            groupEventNeeded = not groupEventStatus
            if (data.questId ~= nil) then
                questNeeded = not HasCompletedQuest(data.questId)
            end
        end

        if (skyshardNeeded == true) or (groupEventNeeded == true) or (questNeeded == true) then
            if (isLocked == true) then
                if (data.isDelve == true) then
                    lockedNeededDelves = lockedNeededDelves + 1
                else
                    lockedNeededDungeons = lockedNeededDungeons + 1
                end
            end

            if (isLocked == false) or ( (isLocked == true) and (SV.infoListsIncludeLocked == true) ) then
                if (data.isDelve == true) then
                    delvesList[data.name] = {
                        zone = (data.parentZoneName),
                        quest = (questNeeded),
                        skyshard = (skyshardNeeded),
                        locked = isLocked,
                    }
                else
                    dungeonsList[data.name] = {
                        zone = (data.parentZoneName),
                        quest = (questNeeded),
                        skyshard = (skyshardNeeded),
                        groupEvent = (groupEventNeeded),
                        locked = isLocked,
                    }
                end
            end
        end
    end

    local delveData = {
        data = delvesList,
        lockedNeeded = lockedNeededDelves,
        lockedTotal = lockedDelvesTotal
    }

    local dungeonData = {
        data = dungeonsList,
        lockedNeeded = lockedNeededDungeons,
        lockedTotal = lockedDungeonsTotal
    }

    return delveData, dungeonData
end

-- Generate the tooltips for when the mouse is over an active delve/dungeon icon
function SPA.CreateTooltipText(control, target)

    if (target == nil) then
        SPA.currentTooltipControl = nil
        SPA.currentTooltipIsDelve = nil
        return
    end

	if (SPA.currentTooltipControl ~= nil) then
		SPA.HideTooltipText()
	end

	InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, TOPRIGHT)

    local output = string.format("%s, %s (%s)", target.zoneName, target.parentZoneName, target.displayName)

	SetTooltipText(InformationTooltip, output)
	SPA.currentTooltipIsDelve = target.isDelve
	SPA.currentTooltipControl = control
	SPA.currentJumpTarget = SPA.U.DeepCopy(target)
end

function SPA.HideTooltipText()
	ZO_Tooltips_HideTextTooltip()
	SPA.currentTooltipControl = nil
	SPA.currentTooltipIsDelve = nil
end

-- when the mouse enters a delve/dungeon button area
function SPA.OnMouseEnter(control, isDelve)
	if (SPA.isInitializing == true) then
		return
	end

	-- return if there are no targets of this type to jump to
	if (control:GetState() == BSTATE_DISABLED) then
		return
	end

	local target = nil 
	if (isDelve == true) then
		target = SPA.delveTarget
	else
		target = SPA.dungeonTarget
	end

	-- ensure we actually have a target
	if (target == nil) then
		return
	end

    SPA.CreateTooltipText(control, target)
end

-- mouse exits a delve/dungeon button area
function SPA.OnMouseExit(control)
    SPA.HideTooltipText()
    SPA.currentTooltipControl = nil
    SPA.currentJumpTarget = nil
    SPA.currentTooltipIsDelve = nil
end

function SPA.ListOnMouseEnter(control)
---@diagnostic disable-next-line: undefined-field
	SPA.delvesList:Row_OnMouseEnter(control)
end

function SPA.ListOnMouseExit(control)
---@diagnostic disable-next-line: undefined-field
	SPA.delvesList:Row_OnMouseExit(control)
end

function SPA.ListOnMouseUp(control, button, upInside, isDelve)
	if (upInside == false) then 
		return
	end

	local nameControl = GetControl(control, "Name")
	local name = nameControl:GetText()
	local zoneId = nil
	local parentZoneId = nil

	for id, data in pairs(SPA.data) do
		if (name == data.name) then
			zoneId = data.zoneId
			parentZoneId = data.parentZoneId
			break
		end
	end

	SCENE_MANAGER:Show("worldMap")

	local delay = 10

	if (parentZoneId == nil) then
		return
	end

	if (SPA.currentMapShowing == 0) or (SPA.currentMapShowing ~= GetMapIndexByZoneId(parentZoneId)) then
		ZO_WorldMap_SetMapByIndex(1)
		SPA.currentMapShowing = GetMapIndexByZoneId(parentZoneId)
		SPA.currentMapZoneId = zoneId
		ZO_WorldMap_SetMapByIndex(SPA.currentMapShowing)
		delay = 175
	end

	if (SV.mapCreateWaypoint == true) then
---@diagnostic disable-next-line: param-type-mismatch, missing-parameter
		PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, SPA.data[zoneId].normalizedX, SPA.data[zoneId].normalizedZ)
	end

	if (SV.mapZoomToTarget == true) then
		zo_callLater(function() ZO_WorldMap_PanToNormalizedPosition(SPA.data[zoneId].normalizedX, SPA.data[zoneId].normalizedZ) end, delay)
	end
end

-- the UI close button is pressed
function SPA.OnCloseButton()
    SPA.wasUiOpenedByHotkey = false
	SPA.wasUiManuallyHidden = true
	SPA.ShowUi(false)

	-- close the Info window with the main UI, unless the Info window was opened by hotkey
    if (SPA.wasInfoOpenedByHotkey == false) then
        SPA.ShowInfo(false)
    end
end

-- When the Info button is pressed. This might show or hide the Info window, as appropriate
function SPA.OnInfoButton()
	if (SPA.isInitializing == true) then
		return
	end

    SPA.ShowInfo()
end

-- The UI close button is pressed
function SPA.OnInfoCloseButton(control)
    SPA.ShowInfo(false)
end

-- One-time, at initialization (first load, or /reloadui) list work
-- Creates the list of zones where this add-on will not be functional. 
-- Also creates the list of quest names for the Public Dungeon quests.
function SPA.CreateZoneLists()
    SPA.excludedZoneIds = {}
    for k, data in pairs(SPA.excludedZoneIdsData) do
        for j, zoneId in pairs(data) do
            SPA.excludedZoneIds[zoneId] = true
        end
    end

    SPA.questNamesList = {}
    for k, data in pairs(SPA.data) do
        if (data.questId ~= nil) then
            table.insert(SPA.questNamesList, GetQuestName(data.questId))
        end
    end
end

-- For retrieving the saved location for the current screen size
-- forMain==true for the main window, forMain==false for the Info window
function SPA.GetSavedLocation(forMain)
	local saved = SV.mainPosition
	if (forMain == false) then
		saved = SV.infoPosition
	end

	local screenWidth = math.floor(GuiRoot:GetWidth())
	local screenHeight = math.floor(GuiRoot:GetHeight())

	local xData, yData

	xData = saved[screenWidth]

	if (xData ~= nil)then
		yData = xData[screenHeight]
		if (yData ~= nil) then
			if (yData.x ~= nil) and (yData.y ~= nil) then
				return yData.x, yData.y
			end
		end
	end

	-- saved data not found
	if (forMain == true) then
		return SPA.mainPositionDefault.x, SPA.mainPositionDefault.y
	end

	-- for Info window, calculate center of screen
	local x = (screenWidth - SPAINFO:GetWidth()) / 2
	local y = (screenHeight - SPAINFO:GetHeight()) / 2

	return x, y
end

-- for retrieving teleport priorities for the settings menu
function SPA.GetTeleportPriorityString()
	if (SV.groupPriority == true) then
		return GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_GROUP)
	end

	if (SV.friendPriority == true) then
		return GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_FRIENDS)
	end

	if (SV.guildPriority == true) then
		return GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_GUILDIES)
	end

	return GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_NONE)
end

-- Save changes to the settings menu teleport priorities
function SPA.SetTeleportPriority(value)
	if (value == GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_GROUP)) then
		SV.groupPriority = true
		SV.friendPriority = false
		SV.guildPriority = false
	end
	if (value == GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_FRIENDS)) then
		SV.groupPriority = false
		SV.friendPriority = true
		SV.guildPriority = false
	end
	if (value == GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_GUILDIES)) then
		SV.groupPriority = false
		SV.friendPriority = false
		SV.guildPriority = true
	end
	if (value == GetString(SPA_SETTINGS_PRIORITY_DROPDOWN_NONE)) then
		SV.groupPriority = false
		SV.friendPriority = false
		SV.guildPriority = false
	end
end

-- Save the Main UI location, filed by screen resolution
function SPA.SaveUiLocation()	
	local screenWidth = math.floor(GuiRoot:GetWidth())
	local screenHeight = math.floor(GuiRoot:GetHeight())

	if (SV.mainPosition[screenWidth] == nil) then
		SV.mainPosition[screenWidth] = {}
	end

	SV.mainPosition[screenWidth][screenHeight] = { ["x"]=SPAUI:GetLeft(), ["y"]=SPAUI:GetTop()}
end

-- Save the Info Window location, filed by screen resolution
function SPA.SaveInfoLocation()
	local screenWidth = math.floor(GuiRoot:GetWidth())
	local screenHeight = math.floor(GuiRoot:GetHeight())

	if (SV.infoPosition[screenWidth] == nil) then
		SV.infoPosition[screenWidth] = {}
	end

    SV.infoPosition[screenWidth][screenHeight] = { ["x"]=SPAINFO:GetLeft(), ["y"]=SPAINFO:GetTop()}
end



function SPA.IsUiHidden()
---@diagnostic disable-next-line: undefined-field
	return not SM:GetScene("hud"):HasFragment(SPA.mainPanelFragment)
end

-- Show the main UI using fragments
function SPA.ShowUi(show)
    if (SPA.mainPanelFragment == nil) then
        SPA.mainPanelFragment = ZO_HUDFadeSceneFragment:New(SPAUI, 0, 0)
    end

	if ( (SPA.wasUiOpenedByHotkey == false) and (show == true) ) then
		if (SPA.isCharacterComplete == true) or (SPA.isExcludedZone == true) then
			return
		end
	end

    -- toggle the UI
    if (show == nil) then
        show = SPA.IsUiHidden()
    end

	-- ******
	-- ****** Continue adding to baertram's stuff?
	-- ******

	---@class ZO_Scene
	local hudScene = SM:GetScene("hud")
	assert(hudScene)

	---@class ZO_Scene
	local huduiScene = SM:GetScene("hudui")
	assert(huduiScene)

    if (show == true) then
		SPA.wasUiManuallyHidden = false
        if (hudScene:HasFragment(SPA.mainPanelFragment) == false) then
            hudScene:AddFragment(SPA.mainPanelFragment)
        end
        if (huduiScene:HasFragment(SPA.mainPanelFragment) == false) then
            huduiScene:AddFragment(SPA.mainPanelFragment)
        end

		-- seems to not automatically unhide in this case
		if (SM:IsShowing("hudui") == true) or (SM:IsShowing("hud") == true) then
        	SPAUI:SetHidden(false)
		end
    else
        if (hudScene:HasFragment(SPA.mainPanelFragment) == true) then
            hudScene:RemoveFragment(SPA.mainPanelFragment)
        end
        if (huduiScene:HasFragment(SPA.mainPanelFragment) == true) then
            huduiScene:RemoveFragment(SPA.mainPanelFragment)
        end
    end
end

-- The Info Window is registered as Top Level, not a fragment
function SPA.ShowInfo(show)
	if (show == nil) then
        show = SPAINFO:IsHidden()
    end

	if (show == true) then
		SPA.UpdateInfoWindow()
		SM:ShowTopLevel(SPAINFO)
	else
		SM:HideTopLevel(SPAINFO)
		SPA.wasInfoOpenedByHotkey = false
	end
end

-- Determine if the player is in a zone we want the add-on disabled for, and
-- take appropriate action
function SPA.ExcludedZoneCheck()
    -- Create the disabled zone list if it hasn't been done
    if (SPA.excludedZoneIds == nil) then
        SPA.CreateZoneLists()
    end

    -- Assume that if the player cannot port to their house, they cannot port to a player
    if (CanJumpToHouseFromCurrentLocation() == false) then
        return true
    end

    if (SPA.excludedZoneIds[SPA.zoneId] == nil) then -- is this zoneId on the disabled list?
        return false
    else
        return true
    end
end

function SPA.KeybindHandler(code)
	if (SPA.isInitializing == true) then
		return
	end

    -- Toggle UI
    if (code == 1) then
        if (SPA.IsUiHidden() == true) then
            SPA.wasUiOpenedByHotkey = true
        else
            SPA.wasUiOpenedByHotkey = false
			if (SPA.wasInfoOpenedByHotkey == false) then
            	SPA.ShowInfo(false) -- hide the info window if the user manually hides the main UI, but only if it wasn't opened manually by hotkey
			end
			SPA.wasUiManuallyHidden = true
		end
		SPA.ShowUi()
    end

    -- Toggle Info window
    if (code == 2) then
		if (SPAINFO:IsHidden() == true) then
			SPA.wasInfoOpenedByHotkey = true
		else
			SPA.wasInfoOpenedByHotkey = false
		end
		
		SPA.ShowInfo()
    end	

    -- Jump to the current overall target by rank points
    if (code == 5) then
        if (SPA.overallTarget ~= nil) then
            SPA.Jump(nil) -- nil represents the overall target
        else
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, SPA_ERROR_NO_TARGET_AVAILABLE)
        end
    end
end

function SPA.RepositionUI()
	-- Main UI
	local x, y = SPA.GetSavedLocation(true)

	-- in case the saved location is off the screen
	if (x < 0) then
		x = 0
	end
	if (y < 0) then
		y = 0
	end

    SPAUI:ClearAnchors()
    SPAUI:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)

	-- Info window
	x, y = SPA.GetSavedLocation(false)

	-- in case the saved location is off the screen
	if (x < 0) then
		x = 0
	end
	if (y < 0) then
		y = 0
	end

    SPAINFO:ClearAnchors()
    SPAINFO:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

-- Generally, to update successfully, call this with a slight delay after the system notifies of a change.
-- Call with no delay if about to show the Info window
function SPA.UpdateInfoWindow()
    local delveSkyshardsNeededCount, pdNeededCount, pdSkyshardsNeededCount, pdEventsNeededCount, pdQuestsNeededCount,
          delvesCount, pdsCount, zoneData = SPA.CountNeeded()

    -- a slight delay seems to be needed here, for the list to show the change
    -- so this method should be called with a delay from things like OnAchievementAwarded
    -- This must happen before the text display, so that the locked counts are updated
    local delvesListData, dungeonsListData = SPA.CreateInfoLists()

    SPA.delvesList.data = delvesListData.data
    SPA.delvesList:Refresh()
    SPA.dungeonsList.data = dungeonsListData.data
    SPA.dungeonsList:Refresh()

	-- If we're hiding locked content, calculate the totals to show
    if (SPA.savedVariables.infoStatsIncludeLocked == false) then
        delvesCount = delvesCount - delvesListData.lockedTotal
		delveSkyshardsNeededCount = delveSkyshardsNeededCount - delvesListData.lockedNeeded
        pdsCount = pdsCount - dungeonsListData.lockedTotal
		pdNeededCount = pdNeededCount - dungeonsListData.lockedNeeded
    end

    local delvesPercent = 100 * (delveSkyshardsNeededCount / delvesCount)
    local delvesPercentText = ""

	if (delvesPercent ~= delvesPercent) then -- NAN check. This occasionally pops up NAN with complete character
		delvesPercent = 0
	end

    if (delvesPercent < 1) and (delvesPercent > 0) then
        delvesPercentText = string.format("%.2f", delvesPercent)
    else
        delvesPercentText = string.format("%.0f", delvesPercent)
    end

    SPAINFO_Delves_Ratio:SetText(zo_strformat(SPA_INFO_DELVES_COMPLETED_RATIO, (delvesCount - delveSkyshardsNeededCount),
                                              delvesCount))
    SPAINFO_Delves_Percent:SetText(zo_strformat(SPA_INFO_DELVES_REMAIN_PERCENT, delvesPercentText))

    if (delvesListData.lockedTotal == 0) or (SV.infoStatsIncludeLocked == true) then
        SPAINFO_Delves_Locked:SetHidden(true)
		SPAINFO_Delves_List:ClearAnchors()
        SPAINFO_Delves_List:SetAnchor(TOPLEFT, SPAINFO_Delves_Percent, BOTTOMLEFT, -25, 10)
        SPAINFO_Delves_List:SetAnchor(BOTTOMRIGHT, SPAINFO_Delves, BOTTOMRIGHT, 0, 0)
    elseif (SV.infoStatsIncludeLocked == false) then
        SPAINFO_Delves_Locked:SetText(zo_strformat(SPA_INFO_DELVES_DLC_LOCKED, delvesListData.lockedTotal))
		SPAINFO_Delves_List:ClearAnchors()
        SPAINFO_Delves_List:SetAnchor(TOPLEFT, SPAINFO_Delves_Locked, BOTTOMLEFT, -25, 10)
        SPAINFO_Delves_List:SetAnchor(BOTTOMRIGHT, SPAINFO_Delves, BOTTOMRIGHT, 0, 0)
		SPAINFO_Delves_Locked:SetHidden(false)
    end

    local dungeonsPercent = 100 * (pdNeededCount / pdsCount)
    local dungeonsPercentText = ""

	if (dungeonsPercent ~= dungeonsPercent) then -- NAN check. This occasionally pops up NAN with complete character
		dungeonsPercent = 0
	end

    if (dungeonsPercent < 1) and (dungeonsPercent > 0) then
        dungeonsPercentText = string.format("%.2f", dungeonsPercent)
    else
        dungeonsPercentText = string.format("%.0f", dungeonsPercent)
    end

    SPAINFO_Dungeons_Ratio:SetText(zo_strformat(SPA_INFO_DUNGEONS_COMPLETED_RATIO, (pdsCount - pdNeededCount), pdsCount))
    SPAINFO_Dungeons_Percent:SetText(zo_strformat(SPA_INFO_DUNGEONS_REMAIN_PERCENT, dungeonsPercentText))

	if (dungeonsListData.lockedTotal == 0) or (SV.infoStatsIncludeLocked == true) then
        SPAINFO_Dungeons_Locked:SetHidden(true)
		SPAINFO_Dungeons_List:ClearAnchors()
        SPAINFO_Dungeons_List:SetAnchor(TOPLEFT, SPAINFO_Dungeons_Percent, BOTTOMLEFT, -25, 10)
        SPAINFO_Dungeons_List:SetAnchor(BOTTOMRIGHT, SPAINFO_Dungeons, BOTTOMRIGHT, 0, 0)
    elseif (SV.infoStatsIncludeLocked == false) then
        SPAINFO_Dungeons_Locked:SetText(zo_strformat(SPA_INFO_DUNGEONS_DLC_LOCKED, dungeonsListData.lockedTotal))
		SPAINFO_Dungeons_List:ClearAnchors()
        SPAINFO_Dungeons_List:SetAnchor(TOPLEFT, SPAINFO_Dungeons_Locked, BOTTOMLEFT, -25, 10)
        SPAINFO_Dungeons_List:SetAnchor(BOTTOMRIGHT, SPAINFO_Dungeons, BOTTOMRIGHT, 0, 0)
        SPAINFO_Dungeons_Locked:SetHidden(false)
    end
end

-- Checking whether the player is "complete", and hide different icons as appropriate
function SPA.CheckCompletionAndProcess()
    local delveSkyshardsNeededCount, pdNeededCount, pdSkyshardsNeededCount, pdEventsNeededCount, pdQuestsNeededCount =
        SPA.CountNeeded()

    if (delveSkyshardsNeededCount == 0) then
        SPAUI_Delve:SetHidden(true)
        SPAUI_Delve_Skyshard:SetHidden(true)
        SPAINFO_Delves_List:SetHidden(true)
    else
        SPAINFO_Delves_List:SetHidden(false)
    end

    if (pdSkyshardsNeededCount == 0) then
        SPAUI_Dungeon_Skyshard:SetHidden(true)
    end

    if (pdQuestsNeededCount == 0) then
        SPAUI_Dungeon_Quest:SetHidden(true)
    end

    if (pdEventsNeededCount == 0) then
        SPAUI_Dungeon_Event:SetHidden(true)
        SPAINFO_Dungeons_List:SetHidden(true)
    end

    if (pdNeededCount == 0) then
        SPAUI_Dungeon:SetHidden(true)
    else
        SPAINFO_Dungeons_List:SetHidden(false)
    end

    if ((delveSkyshardsNeededCount == 0) and (pdNeededCount == 0)) then
        SPA.isCharacterComplete = true
        SPAUI_Complete:SetText(zo_strformat(SPA_CHARACTER_COMPLETE, GetUnitName("player")))
        SPAUI_Complete:SetHidden(false)
    else
        SPA.isCharacterComplete = false
        SPAUI_Complete:SetHidden(true)
    end

    return SPA.isCharacterComplete
end

function SPA.OnPlayerActivatedDelayed()
    SPA.zoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy

	if (SPA.CheckIdsTest == true) then
		d(">>>>>>>>>>>>>>> CheckIds Active <<<<<<<<<<<<<<<")
	end

	-- While testing, I like a marker in the chat text when I've reloaded the UI...
	if ((GetUnitDisplayName("player") == "@Tagarn") or (GetUnitDisplayName("player") == "@TagAgain")) and (SPA.debugOptions == true) and (SPA.reloaded == true) then
		dbg("********************** RELOAD **********************")
	end

    -- Stop any pending *** STA Error: ( SPA.checkCallLater ~= nil ) when (SPA.isExcludedZone == true) inside Check()
    if (SPA.checkCallLater ~= nil) then
        zo_removeCallLater(SPA.checkCallLater)
        SPA.checkCallLater = nil
    end

	-- "New Features" dialog, if last version run is less than when the feature came out
	-- Currently: 110, with clickable delve/dungeon names
	if (SV.versionLastRun == nil) or (SV.versionLastRun < 110) then
		SPA.ShowNewFeatureDialog()
		SV.versionLastRun = SPA.versionNumeric
	end

    -- Check what this character needs
    SPA.CheckCompletionAndProcess()

    if (SPA.isCharacterComplete == true) then
		SPA.ShowUi(false)
		SPA.isInitializing = false
		SPA.reloaded = false
        return
    end

    -- Check if player is in a zone where this add-on should be disabled
    SPA.isExcludedZone = SPA.ExcludedZoneCheck()

	-- Flag as excluded for the next zone load, for bringing back the UI in Check()
	if (SPA.isExcludedZone == true) then
		SPA.lastZoneWasExcluded = true -- safe to set as it is reset in Check(), which is not running for this zone
	end

	-- make sure the UI is showing if it isn't set to autohide
	if (SPA.isExcludedZone == false) and (SV.uiHideEmpty == false) then
		SPA.ShowUi(true)
	elseif (SPA.isExcludedZone == true) then
		SPA.ShowUi(false)
	end

    SPA.ConfigureThisZone()

	if (SPA.inTargetZone == true) then 
		SPA.ShowUi(true)
	end

    -- Check if we successfully jumped to our target
    -- (This would also hold true if the player started a jump, then went through the door to the target zone)
    if (SPA.inTargetZone == true) and (SPA.jumpData ~= nil) then
        if (SPA.zoneId == SPA.jumpData.zoneId) then
            if (SPA.IsZoneADelve(SPA.zoneId) == true) then
                SPA.savedVariables.delvePortsCount = SPA.savedVariables.delvePortsCount + 1
            else
                SPA.savedVariables.pdPortsCount = SPA.savedVariables.pdPortsCount + 1
            end

			-- The Easter Egg
            if (SPA.jumpData.displayName == "@Tagarn") then
                if (SPA.savedVariables.portedToTagCount == 0) then
                    SPA.ShowTagDialog()
					if (SV.firstPortToTag == nil) then
						SV.firstPortToTag = GetTimeStamp()
					end
                end
                SPA.savedVariables.portedToTagCount = SPA.savedVariables.portedToTagCount + 1
            end
        end
    end

	-- Reset jump information
    SPA.currentJumpTarget = nil
    SPA.jumpData = nil

	-- Allow Check() to run
	SPA.isInitializing = false

	-- Don't pop up any first-time-since-load messages
	SPA.reloaded = false

	-- Set up even monitoring
	if (SPA.isExcludedZone == false) then	
		EM:RegisterForEvent(SPA.name .. "OnPlayerDeactivated", EVENT_PLAYER_DEACTIVATED, SPA.OnPlayerDeactivated)
		EM:RegisterForEvent(SPA.name .. "OnSkyshardsUpdated", EVENT_SKYSHARDS_UPDATED, SPA.OnSkyshardsUpdated)
		EM:RegisterForEvent(SPA.name .. "OnAchievementAwarded", EVENT_ACHIEVEMENT_AWARDED, SPA.OnAchievementAwarded)
		EM:RegisterForEvent(SPA.name .. "OnQuestComplete", EVENT_QUEST_COMPLETE, SPA.OnQuestComplete)
		EM:RegisterForEvent(SPA.name .. "OnScreenResized", EVENT_SCREEN_RESIZED, SPA.OnScreenResized)
		EM:RegisterForEvent(SPA.name .. "OnPlayerCombatState", EVENT_PLAYER_COMBAT_STATE, SPA.OnPlayerCombatState)
		
		WORLD_MAP_SCENE:RegisterCallback("StateChange", SPA.OnWorldMapStateChange)
	end

    -- Don't start the friends/guildies list processing if the UI isn't going to be visible.
    -- (Character complete is caught above)
    if (SPA.isExcludedZone == false) then
        SPA.checkCallLater = zo_callLater(function(self)
            SPA.Check()
        end, 100)
    end

	-- Check if the Craglorn Group Delve dialog box should be shown
	if (SV.groupDelveNotification == false) and (SPA.groupDelvesList[SPA.zoneId] ~= nil) then
		SPA.ShowCraglornGroupDelveDialog()
	end
end

function SPA.OnPlayerActivated(eventCode, initial)
	SPA.isInitializing = true

	-- Initially hide the windows
	SPAUI:SetHidden(true)
	SPAINFO:SetHidden(true)

	-- Ensure fragments are reset
	if (SM:GetScene("hud"):HasFragment(SPA.mainPanelFragment) == true) then
		SM:GetScene("hud"):RemoveFragment(SPA.mainPanelFragment)
	end
	if (SM:GetScene("hudui"):HasFragment(SPA.mainPanelFragment) == true) then
		SM:GetScene("hudui"):RemoveFragment(SPA.mainPanelFragment)
	end


    -- We need to delay this as such things as GetSkyshardDiscoveryStatus() are not valid
    -- at this point when a character is first loaded in from the character screen. It *does*
    -- seem to be valid on a /reloadui, though...
    zo_callLater(function(self)
        SPA.OnPlayerActivatedDelayed()
    end, 500)
end

function SPA.OnPlayerDeactivated(eventCode)
	EM:UnregisterForEvent(SPA.name .. "OnPlayerDeactivated", EVENT_PLAYER_DEACTIVATED)
	EM:UnregisterForEvent(SPA.name .. "OnPlayerDeactivated", EVENT_PLAYER_DEACTIVATED)
	EM:UnregisterForEvent(SPA.name .. "OnSkyshardsUpdated", EVENT_SKYSHARDS_UPDATED)
	EM:UnregisterForEvent(SPA.name .. "OnAchievementAwarded", EVENT_ACHIEVEMENT_AWARDED)
	EM:UnregisterForEvent(SPA.name .. "OnQuestComplete", EVENT_QUEST_COMPLETE)
	EM:UnregisterForEvent(SPA.name .. "OnScreenResized", EVENT_SCREEN_RESIZED)
	EM:UnregisterForEvent(SPA.name .. "OnPlayerCombatState", EVENT_PLAYER_COMBAT_STATE)
	
	WORLD_MAP_SCENE:RegisterCallback("StateChange", SPA.OnWorldMapStateChange)
end


function SPA.OnSkyshardsUpdated(...)
    -- only do the deeper check if there's something in this zone to get
    if (SPA.inTargetZone == true) then
        -- For counting how many skyshards have been picked up via this add-on
        -- Check if this is the zone we jumped to, and if we needed the skyshard here
        if (SPA.targetZoneStatus ~= nil) then
            if (SPA.targetZoneStatus.zoneId == SPA.zoneId) and (SPA.targetZoneStatus.skyshardNeeded == true) then
                if (GetSkyshardDiscoveryStatus(SPA.data[SPA.zoneId].skyshardId) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED) then
                    if (SPA.IsZoneADelve(SPA.zoneId) == true) then
                        SPA.savedVariables.delveSkyshardCount = SPA.savedVariables.delveSkyshardCount + 1
                    else
                        SPA.savedVariables.pdSkyshardCount = SPA.savedVariables.pdSkyshardCount + 1
                    end

                    SPA.targetZoneStatus.skyshardNeeded = false
                end
            end
        end

        -- A slight delay here seems to be needed for SPA.UpdateInfoWindow(), at least
        zo_callLater(function(self)
            SPA.UpdateInfoWindow()
            SPA.ConfigureThisZone()
            SPA.CheckCompletionAndProcess()
        end, 100)
    end
end

-- LATER: look at filtering notifications to be more specific?
function SPA.OnAchievementAwarded(eventCode, name, points, id, link)
    -- only do the deeper check if there's something in this zone to get
    if (SPA.inTargetZone == true) then
        local zoneId = GetZoneId(GetUnitZoneIndex("player") or 0) -- "or 0" to keep IDE happy
        -- Check if it is a group event notification
        if (SPA.data[zoneId]) and (SPA.data[zoneId].groupEventId) and (id == SPA.data[zoneId].groupEventId) then
            -- For counting how many Group Events have been done up via this add-on
            -- Check if this is the zone we jumped to, and if we needed the Group Event here
            if (SPA.targetZoneStatus.zoneId == SPA.zoneId) and (SPA.targetZoneStatus.groupEventNeeded == true) then
                local _, _, _, _, groupEventStatus, _, _ = GetAchievementInfo(SPA.data[SPA.zoneId].groupEventId)
                if (groupEventStatus == true) then
                    SPA.savedVariables.pdGroupEventCount = SPA.savedVariables.pdGroupEventCount + 1

                    SPA.targetZoneStatus.groupEventNeeded = false
                end
            end

            -- A slight delay here seems to be needed for SPA.UpdateInfoWindow(), at least
            zo_callLater(function(self)
                SPA.UpdateInfoWindow()
                SPA.ConfigureThisZone()
                SPA.CheckCompletionAndProcess()
            end, 100)
        end
    end
end

-- LATER: look at filtering events, perhaps by questId if we're lucky?
function SPA.OnQuestComplete(eventCode, questName)
    -- match the questName to the list of Public Dungeon quest names
    if (SPA.U.IsInTable(questName, SPA.questNamesList) == true) then
        -- For counting how many Public Dungeon Skill Point Quests have been done up via this add-on
        -- Check if the questId matches the one we last jumped for
        if (SPA.targetZoneStatus ~= nil) and (SPA.targetZoneStatus.questName ~= nil) then
            if (SPA.targetZoneStatus.questName == questName) then
                SPA.savedVariables.pdQuestCount = SPA.savedVariables.pdQuestCount + 1
                SPA.targetZoneStatus.questName = nil
            end
        end

        -- A slight delay here seems to be needed for SPA.UpdateInfoWindow(), at least
        zo_callLater(function(self)
            SPA.UpdateInfoWindow()
            SPA.ConfigureThisZone()
            SPA.CheckCompletionAndProcess()
        end, 100)
    end
end

function SPA.OnScreenResized(eventCode, width, height)
	SPA.RepositionUI()
	-- The lists in the Info window weren't fully populated after a screen resizing, so this will ensure it's fixed
	SPA.UpdateInfoWindow()
end

function SPA.OnSceneStateChange(oldState, newState)
	if (newState == SCENE_HIDDEN) then
		SPA.ShowInfo(false)
	end
end

-- Watching for the map scene to change, so we know if our map is still up
function SPA.OnWorldMapStateChange(oldState, newState)
	if (newState == SCENE_HIDING) then
		SPA.currentMapShowing = 0 -- set this to "none" with a 0
	end
end


-- Hide if UI (if player chooses) when in combat
function SPA.OnPlayerCombatState( eventCode, inCombat)
	-- apparently this can be called before initialize is complete?!?
	if (SV == nil) or (SV.uiHideInCombat == nil) then
		return
	end

	if (SV.uiHideInCombat == true) then 
		if (inCombat == true) then
			SPA.wasUiHiddenByCombat = true
			SPA.ShowUi(false)
			SPA.ShowInfo(false)
		elseif (SPA.wasUiHiddenByCombat == true) then
			SPA.wasUiHiddenByCombat = false
			SPA.ShowUi(true)
		end
	end
end


-- Initialize after a delay to allow output to make it to the chat
function SPA.Initialize()
	SPA.isInitializing = true
	SPA.reloaded = true

    SPA.savedVariables = ZO_SavedVars:NewAccountWide("SkillPointAlertsVars", 1, nil, saveDefaults,
                                                     GetWorldName())
	SV = SPA.savedVariables

	assert(SV)

	if (GetUnitDisplayName("player") == "@Tagarn") and (SPA.debugOptions == true) then
		SLASH_COMMANDS["/t"] = function()
			SPA.Test()
		end
		SLASH_COMMANDS["/test"] = function()
			SPA.Test()
		end
	end

	-- Ensure that saved variables added since this user last updated have a default
	for variable, default in pairs(saveDefaults) do
		if (SV[variable] == nil) then
			SV[variable] = default
		end
	end

	-- Change old variables to new, if they exist
	if (SV.listNoCountLocked ~= nil) then -- From v1.0
		SV.infoStatsIncludeLocked = not SV.listNoCountLocked
		SV.listNoCountLocked = nil
	end
	if (SV.listHideLocked ~= nil) then -- From v1.0
		SV.infoListsIncludeLocked = not SV.listHideLocked
		SV.listHideLocked = nil
	end		
	if (SV.friendPriority == true) and (SV.groupPriority == true) then -- From v1.17
		SV.friendPriority = false
	end

	-- Remove data that's for an upcoming patch
	-- local currentApiLevel = GetAPIVersion()
	-- for id, d in pairs(SPA.data) do
	-- 	if (d.patch) and (d.patch > currentApiLevel) then
	-- 		SPA.data[id] = nil
	-- 	end
	-- end

    -- Just use the keybind handler
    SLASH_COMMANDS["/spaui"] = function()
        SPA.KeybindHandler(1)
    end

    -- Just use the keybind handler
    SLASH_COMMANDS["/spainfo"] = function()
        SPA.KeybindHandler(2)
    end

	-- Just use the keybind handler
	SLASH_COMMANDS["/spat"] = function()
        SPA.KeybindHandler(5)
    end

    -- for showing the stats
    SLASH_COMMANDS["/spastats"] = function()
        SPA.Stats()
    end


    SPA.SettingsMenu.CreateSettingsMenu()
	SPA.RepositionUI()

    -- Initially hide the UI
    SPAUI:SetHidden(true)

    -- Initially hide the Info window
    SPAINFO:SetHidden(true)

    -- Set the version name and show the version box (once main UI is shown), and dynamically adjust the box size
    if (SPA.debugOptions == true) then
        SPAUI_Version:SetText(zo_strformat(SPA_VERSION, SPA.version, SPA.buildNumber))
		local width, height = SPAUI_Version:GetTextDimensions()
		SPAUI_Version:SetDimensions(width, height - 5)
		SPAUI_VersionBox:SetDimensions(width, height - 5)
        SPAUI_VersionBox:SetHidden(false)
    else
        SPAUI_VersionBox:SetHidden(true)
    end

	-- Create a list of Craglorn Group Delves for quick checks later
	SPA.groupDelvesList = {}
	for id, zone in pairs(SPA.data) do
		if (zone.groupDelve == true) then
			SPA.groupDelvesList[id] = zone
		end
	end

	-- The Info window's list boxes
    SPA.delvesList = SFL:New(SPAINFO_Delves_List, false)
    SPA.dungeonsList = SFL:New(SPAINFO_Dungeons_List, true)

    SPA.CreateZoneLists()

	SM:RegisterTopLevel(SPAINFO, false)

	EM:RegisterForEvent(SPA.name, EVENT_PLAYER_ACTIVATED, SPA.OnPlayerActivated)
end

function SPA.OnAddOnLoaded(event, addonName)
    if (addonName == SPA.name) then
        EM:UnregisterForEvent(SPA.name, EVENT_ADD_ON_LOADED)
        SPA.Initialize()
    end
end

EM:RegisterForEvent(SPA.name, EVENT_ADD_ON_LOADED, SPA.OnAddOnLoaded)
