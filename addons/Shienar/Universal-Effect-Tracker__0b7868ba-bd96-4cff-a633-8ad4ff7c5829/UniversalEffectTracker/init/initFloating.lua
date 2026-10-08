--Rotate all floating controls at the same time to avoid recalculations.
local function RotateFloatingControls()
    -- Returns the components of a unit vector in the direction of the player's camera
    local x, y, z = GetCameraForward(SPACE_WORLD)

    --Calculate the orientation of the unit vector.
    --Negate the pitch and Rotate the yaw by 180 degrees so it faces the camera.
    local pitch = -math.asin(-y)
    local yaw = zo_atan2(x, z) - math.pi

    for k, v in pairs(UniversalTracker.FloatingControls.list) do
        for index, data in pairs(v) do
            if data and data.object and not data.object:IsHidden() then
                data.object:SetTransformRotation(pitch, yaw, 0)
            end
        end
    end
end

local function StartMovingControl(trackerID, control, key, unitTag, yOffset)
    if not UniversalTracker.FloatingControls.list[trackerID] then
        UniversalTracker.FloatingControls.list[trackerID] = {}
    end

    table.insert(UniversalTracker.FloatingControls.list[trackerID], {key = key, object = control, unitTag = unitTag})

    UniversalTracker.FloatingControls.totalFloatingControlCount = UniversalTracker.FloatingControls.totalFloatingControlCount + 1

    if UniversalTracker.FloatingControls.totalFloatingControlCount == 1 then
        EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name.."RotateFloatingObjects", 1, RotateFloatingControls)
    end

    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name.."MoveFloatingObject"..control:GetName(), 1, function()
        local _, x, y, z = GetUnitRawWorldPosition(unitTag)
        control:SetTransformOffset(WorldPositionToGuiRender3DPosition(x, y+yOffset, z))
    end)
end

function UniversalTracker.RefreshFloatingList(settingsTable, unitTagPrefix)
    UniversalTracker.ReleaseSingleDisplay(settingsTable)
    for i = 1, 12 do
        if(DoesUnitExist(unitTagPrefix..i)) then
            UniversalTracker.InitFloating(settingsTable, unitTagPrefix..i)
        end
    end
end

function UniversalTracker.InitFloating(settingsTable, unitTag)

    local floatingControl, floatingControlKey = UniversalTracker.floatingPool:AcquireObject()
    floatingControl:SetTransformNormalizedOriginPoint(0.5, 0.5)
    floatingControl:SetSpace(SPACE_WORLD)
    floatingControl:SetTransformScale((1/128) * settingsTable.scale)

    local textureControl = floatingControl:GetNamedChild("Texture")
    if settingsTable.overrideTexturePath == "" then
        textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
    else
        textureControl:SetTexture(settingsTable.overrideTexturePath)
    end

    local durationControl = floatingControl:GetNamedChild("Duration")
    durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
	durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
	durationControl:SetScale(settingsTable.textSettings.duration.textScale)
	durationControl:ClearAnchors()
	durationControl:SetAnchor(CENTER, floatingControl, CENTER, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
    durationControl:SetText("")


    StartMovingControl(settingsTable.id, floatingControl, floatingControlKey, unitTag, 200+settingsTable.y)

    if DoesUnitExist(unitTag) then
        for i = 1, GetNumBuffs(unitTag) do
            local _, startTime, endTime, _, _, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo(unitTag, i)
            if settingsTable.hashedAbilityIDs[abilityId] then
                if settingsTable.overrideTexturePath == "" then
                    textureControl:SetTexture(GetAbilityIcon(abilityId))
                else
                    textureControl:SetTexture(settingsTable.overrideTexturePath)
                end

                UniversalTracker.updateVisibility(floatingControl, true, settingsTable)

				if not IsAbilityPermanent(abilityId) and not UniversalTracker.secretlyPermanent[abilityId] then
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    endTime = endTime*1000

					EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..floatingControl:GetName(), 100, function()
						local duration = (endTime-GetGameTimeMilliseconds())/1000
						if duration < 0 then
							--Effect Expired
							EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..floatingControl:GetName())
							durationControl:SetText("")

                            UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
						else
							if duration < 2 then
								durationControl:SetText(zo_roundToNearest(duration, 0.1))
							else
								durationControl:SetText(zo_roundToZero(duration))
							end
						end
					end)
                end
                break
            end
            UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
        end
    end

    EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..floatingControl:GetName(), EVENT_COMBAT_EVENT, function( _, result, _, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, unitID, abilityID, _)
		if not AreUnitsEqual(unitTag, UniversalTracker.unitIDs[unitID]) then return end

        if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP  then
            floatingControl:SetHidden(true)
        elseif settingsTable.hashedAbilityIDs[abilityID] and not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then

            -- Only track effects not affected by event_effect_changed
			for i = 1, GetNumBuffs(unitTag) do
				local _, _, _, _, _, _, _, _, _, _, buffID, _, _ = GetUnitBuffInfo(unitTag, i)
				if abilityID == buffID then return end
			end

            if result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION then
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(abilityID))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end

                UniversalTracker.updateVisibility(floatingControl, true, settingsTable)

                if not IsAbilityPermanent(abilityID) and not UniversalTracker.secretlyPermanent[abilityID] then
                    local endTime
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = GetGameTimeMilliseconds() + (1000*tonumber(settingsTable.textSettings.duration.overrideDuration))
                    else
                        endTime = GetGameTimeMilliseconds() + hitValue
                    end
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..floatingControl:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..floatingControl:GetName())
                            durationControl:SetText("")
                            UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
                        else
                            if duration < 2 then
                                durationControl:SetText(zo_roundToNearest(duration, 0.1))
                            else
                                durationControl:SetText(zo_roundToZero(duration))
                            end
                        end
                    end)
                end
			elseif result == ACTION_RESULT_EFFECT_FADED and not tonumber(settingsTable.textSettings.duration.overrideDuration) then
                UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
            end
        end
    end)

    EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..floatingControl:GetName(), EVENT_EFFECT_CHANGED, function( _, changeType, _, _, tag, startTime, endTime, stackCount, _, _, _, _, _, _, _, abilityID, sourceType)
		if not AreUnitsEqual(unitTag, tag) then return end

        if settingsTable.hashedAbilityIDs[abilityID] and
			not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then

            if changeType == EFFECT_RESULT_FADED then
			    if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                --if faded with others running then return.
				for i = 1, GetNumBuffs(unitTag) do
					local _, _, _, _, _, _, _, _, _, _, buffID, _, _ = GetUnitBuffInfo(unitTag, i)
					if settingsTable.hashedAbilityIDs[buffID] and abilityID ~= buffID then return end
				end

                UniversalTracker.updateVisibility(floatingControl, false, settingsTable)

			else

                if settingsTable.overrideTexturePath == "" then
                    textureControl:SetTexture(GetAbilityIcon(abilityID))
                else
                    textureControl:SetTexture(settingsTable.overrideTexturePath)
                end

                UniversalTracker.updateVisibility(floatingControl, true, settingsTable)

                if not IsAbilityPermanent(abilityID) and not UniversalTracker.secretlyPermanent[abilityID] then
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    endTime = endTime * 1000
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..floatingControl:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..floatingControl:GetName())
                            durationControl:SetText("")

                            UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
                        else
                            if duration < 2 then
                                durationControl:SetText(zo_roundToNearest(duration, 0.1))
                            else
                                durationControl:SetText(zo_roundToZero(duration))
                            end
                        end
                    end)
                end
            end
        end
    end)

    EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..floatingControl:GetName(), EVENT_UNIT_DEATH_STATE_CHANGED, function(_, tag, isDead)
        if isDead == false and tag == unitTag then
            if settingsTable.hideInactive then durationControl:SetText("") end
            UniversalTracker.updateVisibility(floatingControl, false, settingsTable)
        end
    end)

end