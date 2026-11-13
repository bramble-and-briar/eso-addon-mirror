local LCCC = LibCodesCommonCode
local RCR = Raidificator


--------------------------------------------------------------------------------
-- General: Interface
--------------------------------------------------------------------------------

local ELEMENTS = {
	{ "Time", "/esoui/art/miscellaneous/timer_32.dds" },
	{ "Vitality", "/esoui/art/trials/vitalitydepletion.dds" },
	{ "Score", "/esoui/art/trials/trialpoints_veryhigh.dds" },
	{ "Endless", "/esoui/art/endlessdungeon/icon_progression_arc.dds" },
	-- Alternative icons:
	-- /esoui/art/notifications/gamepad/gp_notificationicon_campaignqueue.dds
	-- /esoui/art/notifications/gamepad/gp_notification_leaderboardaccept_down.dds
	-- /esoui/art/icons/mapkey/mapkey_endlessdungeon.dds
}

local MODE_CONFIGS = {
	[RCR.MODE_DUNGEON] = { Time = "00:00", Vitality = false, Score = false, Endless = false },
	[RCR.MODE_TRIAL] = { Time = "0:00:00", Vitality = "00/00", Score = "000000", Endless = false },
	[RCR.MODE_ENDLESS] = { Time = "0:00:00", Vitality = "0", Score = "000000", Endless = RCR.FormatExtra(0, 0, 0) },
}

RCR.ENDLESS_TYPES = {
	[ENDLESS_DUNGEON_GROUP_TYPE_SOLO] = { "1", 0x00FF00 },
	[ENDLESS_DUNGEON_GROUP_TYPE_DUO ] = { "2", 0x0099FF },
}

local Frame = RaidificatorStatusFrame

function RCR.InitializeStatus( )
	-- Positioning
	local LCA = LibCombatAlerts
	if (LCA and LCCC.GetAddOnVersion("LibCombatAlerts") >= 7010) then
		if (not RCR.vars.pos) then
			-- Migrate to new position format
			RCR.vars.pos = {
				left = RCR.vars.left,
				top = RCR.vars.top,
				right = RCR.vars.right,
			}
		end
		local handler = LCA.MoveableControl:New(Frame)
		handler:UpdatePosition(RCR.vars.pos)
		handler:RegisterCallback(RCR.name, LCA.EVENT_CONTROL_MOVE_STOP, function( pos )
			RCR.vars.pos = pos
			-- Also save legacy position format, for use if LCA is disabled in a future session
			RCR.vars.left = Frame:GetLeft()
			RCR.vars.top = Frame:GetTop()
			RCR.vars.right = nil
		end)
	else
		-- Without LCA, just restore the position and don't bother with movement
		local anchorPoint = (type(RCR.vars.left) == "number") and TOPLEFT or TOPRIGHT
		Frame:SetAnchor(anchorPoint, GuiRoot, anchorPoint, RCR.vars[(anchorPoint == TOPLEFT) and "left" or "right"], RCR.vars.top)
		Frame:SetMovable(false)
	end

	-- Configure background
	RCR.statusElements.bg = Frame:GetNamedChild("Backdrop")
	RCR.statusElements.bg:SetEdgeColor(0, 0, 0, 0)
	RCR.UpdateStatusBackground()

	-- Create and configure elements
	local previousControl = nil
	for _, element in ipairs(ELEMENTS) do
		local elementName, icon = unpack(element)
		local control = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)" .. elementName, Frame, "RaidificatorStatusElement")
		if (not previousControl) then
			control:SetAnchor(TOPLEFT, Frame, TOPLEFT, 4, 4)
		else
			control:SetAnchor(TOPLEFT, previousControl, TOPRIGHT, 24, 0)
		end
		control:GetNamedChild("Icon"):SetTexture(icon)
		control.text = control:GetNamedChild("Text")
		RCR.statusElements[elementName] = control
		previousControl = control
	end

	-- Initialize the indicator for group type
	do
		local element = RCR.statusElements["Endless"]
		local control = WINDOW_MANAGER:CreateControl("$(parent)GroupType", element, CT_TEXTURE)
		control:SetDimensions(12, 12)
		control:SetAnchor(BOTTOMRIGHT, element:GetNamedChild("Icon"))
		element.gtype = control
	end

	-- Create scene fragment
	RCR.statusFragment = ZO_SimpleSceneFragment:New(Frame)

	LCCC.MonitorZoneChanges(RCR.name, RCR.OnNewZone)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_PLAYER_ACTIVATED, function() zo_callLater(RCR.ZoneSanityCheck, 1500) end)

	-- Dungeons
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, RCR.OnActivityFinderStatusUpdate)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_PLAYER_DEACTIVATED, RCR.OnPlayerDeactivated)

	-- Trials
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_RAID_TRIAL_STARTED, RCR.OnRaidTrialStarted)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_RAID_TRIAL_COMPLETE, RCR.OnRaidTrialComplete)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_RAID_TRIAL_FAILED, RCR.OnRaidTrialFailed)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_RAID_REVIVE_COUNTER_UPDATE, RCR.OnRaidReviveCounterUpdate)

	-- Endless
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ENDLESS_DUNGEON_STARTED, RCR.OnEndlessDungeonStarted)
	EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ENDLESS_DUNGEON_COMPLETED, RCR.OnEndlessDungeonCompleted)
end

function RCR.SwitchMode( mode, delay )
	if (delay) then
		zo_callLater(function() RCR.SwitchMode(mode) end, delay)
		return
	end

	RCR.ToggleEncounterLog(mode)

	-- Do nothing else if there is no mode change
	if (RCR.statusMode == mode) then return end

	-- Clean up previous modes
	if (RCR.statusMode == RCR.MODE_DUNGEON) then
		EVENT_MANAGER:UnregisterForEvent(RCR.name, EVENT_PLAYER_COMBAT_STATE)
		EVENT_MANAGER:UnregisterForEvent(RCR.name, EVENT_ZONE_CHANGED)
		RCR.vars.startTime = 0
	end

	-- Enable new mode
	RCR.statusMode = mode

	if (mode == RCR.MODE_INACTIVE or RCR.specialZone) then
		-- Stop polling and hide after a minute
		EVENT_MANAGER:UnregisterForUpdate(RCR.name)
		zo_callLater(RCR.ToggleStatusVisibility, 60000)
	else
		-- Set up status elements
		for elementName, widthText in pairs(MODE_CONFIGS[mode]) do
			local control = RCR.statusElements[elementName]
			if (widthText) then
				control.text:SetText("")
				control.text:SetDimensionConstraints(control.text:GetStringWidth(widthText) / GetUIGlobalScale(), 0, 0, 0)
				control:SetHidden(false)
			else
				control:SetHidden(true)
			end
		end

		-- Force size recalculation for the overall frame
		Frame:SetWidth(1)
		Frame:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)

		if (mode == RCR.MODE_DUNGEON) then
			-- Stuff to handle dungeon start detection
			EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_PLAYER_COMBAT_STATE, RCR.OnPlayerCombatState)
			EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ZONE_CHANGED, RCR.OnZoneChanged)
			if (IsUnitInCombat("player")) then
				RCR.OnPlayerCombatState(nil, true)
			end
		elseif (mode == RCR.MODE_TRIAL) then
			RCR.InitializeTrial()
		end

		-- Start polling and unhide
		EVENT_MANAGER:RegisterForUpdate(RCR.name, RCR.pollingInterval, RCR.Poll)
		RCR.Poll()
		RCR.ToggleStatusVisibility(true)
	end
end

function RCR.ToggleStatusVisibility( visible )
	if (visible == true) then
		if (not RCR.statusVisible) then
			RCR.statusVisible = true
			HUD_SCENE:AddFragment(RCR.statusFragment)
			HUD_UI_SCENE:AddFragment(RCR.statusFragment)
		end
	else
		if (RCR.statusVisible and RCR.statusMode == RCR.MODE_INACTIVE) then
			RCR.statusVisible = false
			HUD_SCENE:RemoveFragment(RCR.statusFragment)
			HUD_UI_SCENE:RemoveFragment(RCR.statusFragment)
		end
	end
end

function RCR.UpdateStatusElement( elementName, text, penalty )
	RCR.statusElements[elementName].text:SetText(text)
	RCR.statusElements[elementName].text:SetColor(LCCC.Int24ToRGBA(penalty and 0xFF3333 or 0xFFFFFF))
end

function RCR.UpdateStatusGroupType( groupType )
	local control = RCR.statusElements["Endless"].gtype
	if (control.currentType ~= groupType) then
		control.currentType = groupType
		groupType = RCR.ENDLESS_TYPES[groupType]
		control:SetTexture(RCR.GetTexture(groupType[1]))
		control:SetColor(LCCC.Int24ToRGBA(groupType[2]))
	end
end

function RCR.UpdateStatusBackground( )
	RCR.statusElements.bg:SetCenterColor(LCCC.Int32ToRGBA(RCR.vars.bgColor))
end


--------------------------------------------------------------------------------
-- General: Updates
--------------------------------------------------------------------------------

function RCR.OnNewZone( zoneId )
	-- Add a half-second processing delay to avoid race condition bugs
	zo_callLater(function() RCR.OnNewZoneDelayed(zoneId) end, 500)
end

function RCR.OnNewZoneDelayed( zoneId )
	RCR.HandleSpecialZones(zoneId)

	if (RCR.specialZone) then
		-- Already handled
	elseif (IsRaidInProgress()) then
		RCR.SwitchMode(RCR.MODE_TRIAL)
	elseif (IsEndlessDungeonStarted()) then
		RCR.SwitchMode(RCR.MODE_ENDLESS)
	else
		local dungeon = RCR.ZONES.D[zoneId]
		if (dungeon and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN) then
			RCR.condition = (dungeon[1] == -1) and 0 or dungeon[1]
			RCR.speedrun = dungeon[2] * 60
			if (RCR.vars.zoneId ~= zoneId) then
				RCR.vars.startTime = 0
			end
			RCR.SwitchMode(RCR.MODE_DUNGEON)
		else
			RCR.SwitchMode(RCR.MODE_INACTIVE)
		end
	end
	RCR.vars.zoneId = zoneId
	RCR.HandleSpecialDungeons()
end

function RCR.ZoneSanityCheck( )
	-- Handle edge case where someone in instance A ports directly to
	-- instance B (avoiding rezone event) after instance B has started
	if (RCR.statusMode ~= RCR.MODE_TRIAL and IsRaidInProgress()) then
		RCR.SwitchMode(RCR.MODE_TRIAL)
	elseif (RCR.statusMode ~= RCR.MODE_ENDLESS and IsEndlessDungeonStarted()) then
		RCR.SwitchMode(RCR.MODE_ENDLESS)
	end
end

function RCR.Poll( )
	if (RCR.statusMode == RCR.MODE_DUNGEON) then
		local elapsedS = (RCR.vars.startTime > 0) and GetTimeStamp() - RCR.vars.startTime or 0
		RCR.UpdateStatusElement("Time", RCR.FormatTime(elapsedS * 1000, 1), elapsedS > RCR.speedrun)
	elseif (RCR.statusMode == RCR.MODE_TRIAL) then
		if (IsRaidInProgress()) then
			local elapsedMS = GetRaidDuration()
			RCR.UpdateStatusElement("Time", RCR.FormatTime(elapsedMS), elapsedMS > RCR.targetTime)
			RCR.UpdateStatusElement("Score", GetCurrentRaidScore())
		end
	elseif (RCR.statusMode == RCR.MODE_ENDLESS) then
		if (IsInstanceEndlessDungeon()) then
			local elapsedMS = GetEndlessDungeonFinalRunTimeMilliseconds()
			if (elapsedMS == 0) then
				local startTime = GetEndlessDungeonStartTimeMilliseconds()
				if (startTime > 0) then
					elapsedMS = GetTimeStamp() * 1000 - startTime
				end
			end
			RCR.UpdateStatusElement("Time", RCR.FormatTime(elapsedMS))
			RCR.UpdateStatusElement("Vitality", GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_WIPES_REMAINING))
			RCR.UpdateStatusElement("Score", GetEndlessDungeonScore())
			RCR.UpdateStatusElement("Endless", RCR.FormatExtra(RCR.GetEndlessProgress()))
			RCR.UpdateStatusGroupType(GetEndlessDungeonGroupType())
		end
	end
end


--------------------------------------------------------------------------------
-- Special Zones (e.g., Night Market)
-- This is for auto-logging without the status bar
--------------------------------------------------------------------------------

function RCR.HandleSpecialZones( zoneId )
	if (RCR.SPECIAL_ZONES[zoneId]) then
		RCR.specialZone = true
		local modes = {
			D = RCR.MODE_DUNGEON,
			T = RCR.MODE_TRIAL,
			A = RCR.MODE_TRIAL,
		}
		RCR.SwitchMode(modes[RCR.GetZoneClassification(zoneId)] or RCR.MODE_INACTIVE)
	elseif (RCR.ZONES.S[zoneId]) then
		RCR.specialZone = true
		RCR.SwitchMode(RCR.MODE_DUNGEON)
	else
		RCR.specialZone = false
	end
end


--------------------------------------------------------------------------------
-- Dungeons
--------------------------------------------------------------------------------

function RCR.OnActivityFinderStatusUpdate( eventCode, result )
	-- Cover the case where a group requeues directly into the same dungeon.
	-- The forming group signal is the closest approximation to the start of a
	-- queued instance since ACTIVITY_FINDER_STATUS_IN_PROGRESS can be signaled
	-- by a reload.
	if (result == ACTIVITY_FINDER_STATUS_FORMING_GROUP or result == ACTIVITY_FINDER_STATUS_READY_CHECK) then
		RCR.lastQueue = GetGameTimeMilliseconds()
	end
end

function RCR.OnPlayerDeactivated( eventCode )
	if (GetGameTimeMilliseconds() - RCR.lastQueue < 180000) then
		RCR.vars.startTime = 0
		RCR.lastQueue = 0
	end
end

function RCR.OnPlayerCombatState( eventCode, inCombat )
	if (inCombat and (RCR.condition == 0 or (RCR.condition > 0 and GetUnitName("boss1") ~= ""))) then
		RCR.StartTimer()
	end
end

function RCR.OnZoneChanged( eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId )
	if (subZoneId ~= 0 and RCR.condition == subZoneId) then
		RCR.StartTimer()
	end
end

function RCR.StartTimer( )
	if (RCR.vars.startTime == 0) then
		RCR.vars.startTime = GetTimeStamp()
		RCR.RequestDataFlush()
	end
end

function RCR.HandleSpecialDungeons( )
	if (RCR.vars.zoneId == 1153) then
		-- Unhallowed Grave
		if (not RCR.special_1153) then
			RCR.special_1153 = true
			EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_COMBAT_EVENT, RCR.StartTimer)
			EVENT_MANAGER:AddFilterForEvent(RCR.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 131774)
			EVENT_MANAGER:AddFilterForEvent(RCR.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
		end
	else
		if (RCR.special_1153) then
			RCR.special_1153 = nil
			EVENT_MANAGER:UnregisterForEvent(RCR.name, EVENT_COMBAT_EVENT)
		end
	end
end


--------------------------------------------------------------------------------
-- Trials
--------------------------------------------------------------------------------

function RCR.InitializeTrial( )
	RCR.raidId = GetCurrentParticipatingRaidId()
	RCR.vitality = GetRaidReviveCountersRemaining()
	RCR.vitalityMax = GetCurrentRaidStartingReviveCounters()
	RCR.targetTime = GetRaidTargetTime()
	RCR.OnRaidReviveCounterUpdate(nil, RCR.vitality)
end

function RCR.OnRaidTrialStarted( eventCode, trialName, weekly )
	RCR.SwitchMode(RCR.MODE_TRIAL)
	RCR.Msg(zo_strformat(SI_RCR_MESSAGE_TRIAL_START,
		trialName,
		RCR.targetTime / 60000
	))
end

function RCR.OnRaidTrialComplete( eventCode, trialName, score, totalTime )
	RCR.UpdateStatusElement("Time", RCR.FormatTime(totalTime), totalTime > RCR.targetTime)
	RCR.UpdateStatusElement("Score", score)
	RCR.Msg(zo_strformat(SI_RCR_MESSAGE_TRIAL_END,
		trialName,
		score,
		RCR.FormatExtra(RCR.vitality, RCR.vitalityMax),
		RCR.FormatTime(totalTime, 3),
		GetString("SI_RCR_MESSAGE_TRIAL_END", (totalTime > RCR.targetTime) and 2 or 1),
		RCR.targetTime / 60000,
		RCR.FormatTime(zo_abs(totalTime - RCR.targetTime), 2)
	))
	RCR.SaveHistoryItem("R", RCR.raidId, score, totalTime, { RCR.vitality, RCR.vitalityMax })
end

function RCR.OnRaidTrialFailed( eventCode, trialName, score )
	RCR.UpdateStatusElement("Score", score)
end

function RCR.OnRaidReviveCounterUpdate( eventCode, currentCounter, countDelta )
	if (RCR.statusMode == RCR.MODE_TRIAL) then
		RCR.UpdateStatusElement("Vitality", RCR.FormatExtra(currentCounter, RCR.vitalityMax), currentCounter <= 0)
		RCR.vitality = currentCounter
	end
end


--------------------------------------------------------------------------------
-- Endless
--------------------------------------------------------------------------------

function RCR.GetEndlessProgress( )
	return GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_ARC), GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_CYCLE), GetEndlessDungeonCounterValue(ENDLESS_DUNGEON_COUNTER_TYPE_STAGE), GetEndlessDungeonGroupType()
end

function RCR.OnEndlessDungeonStarted( eventCode )
	RCR.SwitchMode(RCR.MODE_ENDLESS)
end

function RCR.OnEndlessDungeonCompleted( eventCode, flags )
	RCR.SaveHistoryItem("E", DEFAULT_ENDLESS_DUNGEON_ID, GetEndlessDungeonScore(), GetEndlessDungeonFinalRunTimeMilliseconds(), { RCR.GetEndlessProgress() })
end
