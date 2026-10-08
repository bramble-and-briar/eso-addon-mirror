UniversalTracker = UniversalTracker or {}
UniversalTracker.name = "UniversalEffectTracker"

UniversalTracker.defaults = {
	nextID = 0,
	nextSetupID = 0,
	trackerList = {

	},
	setupList = {

	},
}

UniversalTracker.defaultsCharacter = {
	trackerList = {

	},
	setupList = {

	},
}

-- Some AbilityIDs are permanent but return false to IsAbilityPermanent() for some reason.
UniversalTracker.secretlyPermanent = {
	-- Nothing Wasted
	[263461] = true,
	[263462] = true
}

UniversalTracker.unitIDs = {}

-- A tracker's userdata objects are stored in these tables at index [id], not in the saved variables.
UniversalTracker.Controls = {}
UniversalTracker.Animations = {}

-- A seperate table for floating controls instead of UniversalTracker.Controls
-- Contains subtables at index [id] of {key, object, unitTag}
UniversalTracker.FloatingControls = {
	totalFloatingControlCount = 0,
	list = {}
}

--Used for the all target ype.
--table[unitID] = {{key, trackerID}, {key, trackerID}, ...}
UniversalTracker.targetIDs_Compact = {}
UniversalTracker.targetIDs_Bar = {}
UniversalTracker.targetIDs_BarAnimation = {}


function UniversalTracker.ReleaseSingleDisplay(settingsTable)
	--Unregister and free existing trackers from this table.
	if settingsTable.id then
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_EFFECT_CHANGED)

		if UniversalTracker.FloatingControls.list[settingsTable.id] and #UniversalTracker.FloatingControls.list[settingsTable.id] > 0 then
			for k, v in pairs(UniversalTracker.FloatingControls.list[settingsTable.id]) do
				UniversalTracker.floatingPool:ReleaseObject(v.key)
				EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name.."MoveFloatingObject"..v.object:GetName().."Texture")
				UniversalTracker.FloatingControls.totalFloatingControlCount = UniversalTracker.FloatingControls.totalFloatingControlCount - 1
			end
			EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_JOINED)
			EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_LEFT)
		elseif UniversalTracker.Controls[settingsTable.id] then
			if UniversalTracker.Controls[settingsTable.id][1] or
				not next(UniversalTracker.Controls[settingsTable.id]) -- initialized but empty table (e.g. initialized boss tracker but no nearby bosses)
			then
					UniversalTracker.freeLists(settingsTable)
			end

			if UniversalTracker.Controls[settingsTable.id].object then
				if string.find(UniversalTracker.Controls[settingsTable.id].object:GetName(), "Bar") then
					UniversalTracker.barAnimationPool:ReleaseObject(UniversalTracker.Animations[settingsTable.id].key)
					UniversalTracker.barPool:ReleaseObject(UniversalTracker.Controls[settingsTable.id].key)
				elseif string.find(UniversalTracker.Controls[settingsTable.id].object:GetName(), "Compact") then
					UniversalTracker.compactPool:ReleaseObject(UniversalTracker.Controls[settingsTable.id].key)
				end
			end
		end

		if UniversalTracker.FloatingControls.totalFloatingControlCount == 0 then
			EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name.."RotateFloatingObjects")
		end

		UniversalTracker.FloatingControls.list[settingsTable.id] = nil
		UniversalTracker.Controls[settingsTable.id] = {}
		UniversalTracker.Animations[settingsTable.id] = {}
	end
end

function UniversalTracker.InitSingleDisplay(settingsTable)

	UniversalTracker.ReleaseSingleDisplay(settingsTable)

	if settingsTable.hidden or
		(tonumber(settingsTable.requiredZoneID) and not UniversalTracker.isInZone(tonumber(settingsTable.requiredZoneID))) or
		(tonumber(settingsTable.requiredSetID) and not UniversalTracker.isWearingFullSet(tonumber(settingsTable.requiredSetID))) or
		(tonumber(settingsTable.requiredSkillID) and not UniversalTracker.hasSkillEquipped(tonumber(settingsTable.requiredSkillID)))
	then
		return
	end

	local unitTag = nil
	if settingsTable.targetType == "Player" then
		unitTag = "player"
	elseif settingsTable.targetType == "Reticle Target" then
		unitTag = "reticleover"
	elseif settingsTable.targetType == "Boss" then
		unitTag = "boss"
	elseif settingsTable.targetType == "Group" then
		unitTag = "group"
	end

	if settingsTable.type == "Floating" then
		if unitTag == "player" then
			UniversalTracker.InitFloating(settingsTable, unitTag)
		elseif unitTag == "group" then
			UniversalTracker.RefreshFloatingList(settingsTable, unitTag)
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_JOINED, function() UniversalTracker.RefreshFloatingList(settingsTable, unitTag) end)
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_LEFT, function() UniversalTracker.RefreshFloatingList(settingsTable, unitTag) end)
		end
	elseif unitTag == "player" or unitTag == "reticleover" then
		if settingsTable.type == "Compact" then
			UniversalTracker.Controls[settingsTable.id].object, UniversalTracker.Controls[settingsTable.id].key = UniversalTracker.compactPool:AcquireObject()

			UniversalTracker.InitCompact(settingsTable, unitTag, UniversalTracker.Controls[settingsTable.id].object)
		elseif settingsTable.type == "Bar" then
			UniversalTracker.Controls[settingsTable.id].object, UniversalTracker.Controls[settingsTable.id].key = UniversalTracker.barPool:AcquireObject()
			UniversalTracker.Animations[settingsTable.id].object, UniversalTracker.Animations[settingsTable.id].key = UniversalTracker.barAnimationPool:AcquireObject()

			UniversalTracker.InitBar(settingsTable, unitTag, UniversalTracker.Controls[settingsTable.id].object, UniversalTracker.Animations[settingsTable.id].object)
		end
	elseif unitTag == "boss" or unitTag == "group" then
		UniversalTracker.InitList(settingsTable, unitTag)

		--register events.
		EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_DEATH_STATE_CHANGED, function() UniversalTracker.updateList(settingsTable, unitTag) end)
		EVENT_MANAGER:AddFilterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, unitTag)
		if unitTag == "boss" then
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_BOSSES_CHANGED, function() UniversalTracker.updateList(settingsTable, unitTag) end)
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_CREATED, function() UniversalTracker.updateList(settingsTable, unitTag) end)
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_DESTROYED, function() UniversalTracker.updateList(settingsTable, unitTag) end)
			EVENT_MANAGER:AddFilterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_CREATED, REGISTER_FILTER_UNIT_TAG_PREFIX, unitTag)
			EVENT_MANAGER:AddFilterForEvent(UniversalTracker.name..settingsTable.id, EVENT_UNIT_DESTROYED, REGISTER_FILTER_UNIT_TAG_PREFIX, unitTag)
		elseif unitTag == "group" then
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_JOINED, function() UniversalTracker.updateList(settingsTable, unitTag) end)
			EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_GROUP_MEMBER_LEFT, function() UniversalTracker.updateList(settingsTable, unitTag) end)
		end
	elseif settingsTable.targetType == "All" then
		UniversalTracker.InitAll(settingsTable)
	end
end

function UniversalTracker.Initialize()
	UniversalTracker.savedVariables = ZO_SavedVars:NewAccountWide("UniversalTrackerSavedVariables", 1, nil, UniversalTracker.defaults, GetWorldName())
	UniversalTracker.characterSavedVariables = ZO_SavedVars:NewCharacterIdSettings("UniversalTrackerSavedVariables", 1, nil, UniversalTracker.defaultsCharacter, GetWorldName())

	UniversalTracker.chat = LibChatMessage("UniversalTracker", "UniversalTracker")

    UniversalTracker.barPool = ZO_ControlPool:New("SingleBarDuration", GuiRoot)
    UniversalTracker.barPool:SetResetFunction(function(control)
		control:SetHidden(true)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_RETICLE_TARGET_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_EFFECT_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
	end)

	UniversalTracker.barAnimationPool = ZO_AnimationPool:New("SingleBarAnimation")

	UniversalTracker.compactPool = ZO_ControlPool:New("SingleCompactTracker", GuiRoot)
    UniversalTracker.compactPool:SetResetFunction(function(control)
		control:SetHidden(true)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_RETICLE_TARGET_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_EFFECT_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
	end)

	UniversalTracker.floatingPool = ZO_ControlPool:New("SingleFloatingTracker", GuiRoot)
	UniversalTracker.floatingPool:SetResetFunction(function(control)
		control:SetHidden(true)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_EFFECT_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name..control:GetName(), EVENT_UNIT_DEATH_STATE_CHANGED)
	end)

    UniversalTracker.InitSettings()

	for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
		if v.hidden then
			--Delay initialization for hidden displays.
			zo_callLater(function() UniversalTracker.InitSingleDisplay(v) end, 10000)
		else
			UniversalTracker.InitSingleDisplay(v)
		end
	end
	for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
		if v.hidden then
			--Delay initialization for hidden displays.
			zo_callLater(function() UniversalTracker.InitSingleDisplay(v) end, 10000)
		else
			UniversalTracker.InitSingleDisplay(v)
		end
	end

	if LibRadialMenu then
		LibRadialMenu:RegisterAddon(UniversalTracker.name, UniversalTracker.name)
		for k, v in pairs(UniversalTracker.savedVariables.setupList) do
			if v and v.id and v.name then
				LibRadialMenu:RegisterEntry(UniversalTracker.name, v.name, tostring(v.id), "EsoUI/Art/Notifications/notificationIcon_duel.dds", function() UniversalTracker.loadSetup(v.id) end, "Load this setup.")
			end
		end
		for k, v in pairs(UniversalTracker.characterSavedVariables.setupList) do
			if v and v.id and v.name then
				LibRadialMenu:RegisterEntry(UniversalTracker.name, v.name, tostring(v.id), "EsoUI/Art/Notifications/notificationIcon_duel.dds", function() UniversalTracker.loadSetup(v.id) end, "Load this setup.")
			end
		end
	end


	HUD_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			--release settings preview

			--unhide everything.
			for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
				if UniversalTracker.Controls[v.id] then
					if UniversalTracker.Controls[v.id].object and
						not (v.hideInactive and
						((v.type == "Compact" and UniversalTracker.Controls[v.id].object:GetNamedChild("Duration"):GetText() == "") or
						(v.type == "Bar" and UniversalTracker.Controls[v.id].object:GetNamedChild("Bar"):GetValue() == 0)))
					then
						UniversalTracker.Controls[v.id].object:SetHidden(v.hidden)
					else
						for i = 1, #UniversalTracker.Controls[v.id] do
							if UniversalTracker.Controls[v.id][i].object and
								not (v.hideInactive and
								((v.type == "Compact" and UniversalTracker.Controls[v.id][i].object:GetNamedChild("Duration"):GetText() == "") or
								(v.type == "Bar" and UniversalTracker.Controls[v.id][i].object:GetNamedChild("Bar"):GetValue() == 0)))
							then
								UniversalTracker.Controls[v.id][i].object:SetHidden(v.hidden)
							end
						end
					end
				end
			end
			for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
				if UniversalTracker.Controls[v.id] then
					if UniversalTracker.Controls[v.id].object and
						not (v.hideInactive and
						((v.type == "Compact" and UniversalTracker.Controls[v.id].object:GetNamedChild("Duration"):GetText() == "") or
						(v.type == "Bar" and UniversalTracker.Controls[v.id].object:GetNamedChild("Bar"):GetValue() == 0)))
					then
						UniversalTracker.Controls[v.id].object:SetHidden(v.hidden)
					else
						for i = 1, #UniversalTracker.Controls[v.id] do
							if UniversalTracker.Controls[v.id][i].object and
								not (v.hideInactive and
								((v.type == "Compact" and UniversalTracker.Controls[v.id][i].object:GetNamedChild("Duration"):GetText() == "") or
								(v.type == "Bar" and UniversalTracker.Controls[v.id][i].object:GetNamedChild("Bar"):GetValue() == 0)))
							then
								UniversalTracker.Controls[v.id][i].object:SetHidden(v.hidden)
							end
						end
					end
				end
			end
		elseif newState == SCENE_FRAGMENT_HIDDEN then
			--hide everything.
			for k, v in pairs(UniversalTracker.savedVariables.trackerList) do
				if UniversalTracker.Controls[v.id] then
					if UniversalTracker.Controls[v.id].object then
						UniversalTracker.Controls[v.id].object:SetHidden(true)
					else
						for i = 1, #UniversalTracker.Controls[v.id] do
							if UniversalTracker.Controls[v.id][i].object then
								UniversalTracker.Controls[v.id][i].object:SetHidden(true)
							end
						end
					end
				end
			end
			for k, v in pairs(UniversalTracker.characterSavedVariables.trackerList) do
				if UniversalTracker.Controls[v.id] then
					if UniversalTracker.Controls[v.id].object then
						UniversalTracker.Controls[v.id].object:SetHidden(true)
					else
						for i = 1, #UniversalTracker.Controls[v.id] do
							if UniversalTracker.Controls[v.id][i].object then
								UniversalTracker.Controls[v.id][i].object:SetHidden(v.hidden)
							end
						end
					end
				end
			end
		end
	end)

	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.."_IDScan", EVENT_EFFECT_CHANGED, function(_, changeType, effectSlot, _, tag, startTime, endTime, _, _, _, _, _, _, _, unitID, abilityID, _)
		if tag == "reticleover" or not UniversalTracker.unitIDs[unitID] then
			UniversalTracker.unitIDs[unitID] = tag
		end
	end)
	local function resetIDList()
		UniversalTracker.unitIDs = {}
	end
	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.."_IDClear", EVENT_BOSSES_CHANGED, resetIDList)
	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.."_IDClear", EVENT_GROUP_MEMBER_JOINED, resetIDList)
	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.."_IDClear", EVENT_GROUP_MEMBER_LEFT, resetIDList)

end

function UniversalTracker.OnAddOnLoaded(event, addonName)
	if addonName == UniversalTracker.name then
		UniversalTracker.Initialize()
		EVENT_MANAGER:UnregisterForEvent(UniversalTracker.name, EVENT_ADD_ON_LOADED)
	end
end

EVENT_MANAGER:RegisterForEvent(UniversalTracker.name, EVENT_ADD_ON_LOADED, UniversalTracker.OnAddOnLoaded)