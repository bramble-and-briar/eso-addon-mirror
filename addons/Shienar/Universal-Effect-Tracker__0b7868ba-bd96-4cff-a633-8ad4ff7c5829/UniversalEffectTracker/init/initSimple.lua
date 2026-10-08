UniversalTracker = UniversalTracker or {}

function UniversalTracker.updateVisibility(control, isActive, settingsTable)
    if isActive then
        if settingsTable.hideInactive then
            if settingsTable.type == "Floating" then control:SetHidden(false)
            elseif HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) end
        elseif settingsTable.hideActive then
            control:SetHidden(true)
        end
    else
        if settingsTable.hideInactive then
            control:SetHidden(true)
        elseif settingsTable.hideActive then
            if settingsTable.type == "Floating" then control:SetHidden(false)
            elseif HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) end
        end
    end

    UniversalTracker.UpdateListAnchors(settingsTable)
end

function UniversalTracker.InitCompact(settingsTable, unitTag, control)
	-- Assign values to created controls.

	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settingsTable.x, settingsTable.y)
	control:SetScale(settingsTable.scale)
	if settingsTable.hideInactive or HUD_FRAGMENT.state == "hidden" then control:SetHidden(true) else control:SetHidden(false) end

	local textureControl = control:GetNamedChild("Texture")
	local durationControl = control:GetNamedChild("Duration")
	local stackControl = control:GetNamedChild("Stacks")
	local unitNameControl = control:GetNamedChild("UnitName")

	durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
	durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
	durationControl:SetScale(settingsTable.textSettings.duration.textScale)
	durationControl:ClearAnchors()
	durationControl:SetAnchor(CENTER, control, CENTER, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
	durationControl:SetText("")

	stackControl:SetHidden(settingsTable.textSettings.stacks.hidden)
	stackControl:SetColor(settingsTable.textSettings.stacks.color.r, settingsTable.textSettings.stacks.color.g, settingsTable.textSettings.stacks.color.b, settingsTable.textSettings.stacks.color.a)
	stackControl:SetScale(settingsTable.textSettings.stacks.textScale)
	stackControl:ClearAnchors()
	stackControl:SetAnchor(TOPRIGHT, control, TOPRIGHT, settingsTable.textSettings.stacks.x - 5, settingsTable.textSettings.stacks.y)
	stackControl:SetText("")

	unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
	unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
	unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
	unitNameControl:ClearAnchors()
	unitNameControl:SetAnchor(BOTTOM, control, TOP, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
	if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
		unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
	else
		unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
	end

	if settingsTable.overrideTexturePath == "" then
		textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
	else
		textureControl:SetTexture(settingsTable.overrideTexturePath)
	end

	--check for current active effects.
	if DoesUnitExist(unitTag) then
		for i = 1, GetNumBuffs(unitTag) do
			local _, startTime, endTime, _, stacks, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo(unitTag, i)
			if settingsTable.hashedAbilityIDs[abilityId] then
                UniversalTracker.updateVisibility(control, true, settingsTable)

				if stacks == 0 then stacks = "" end
				stackControl:SetText(stacks)
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(abilityId))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end
				if not IsAbilityPermanent(abilityId) and not UniversalTracker.secretlyPermanent[abilityId] then
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    endTime = endTime*1000
					EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
						local duration = (endTime-GetGameTimeMilliseconds())/1000
						if duration < 0 then
							--Effect Expired
							EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
							if settingsTable.overrideTexturePath == "" then
								textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
							else
								textureControl:SetTexture(settingsTable.overrideTexturePath)
							end
							durationControl:SetText("")
							stackControl:SetText("")
                            UniversalTracker.updateVisibility(control, false, settingsTable)
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
		end
	end

	if unitTag == "reticleover" then
		EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..control:GetName(), EVENT_RETICLE_TARGET_CHANGED, function()
			if DoesUnitExist(unitTag) then
				if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
				elseif GetUnitName(unitTag) ~= "" then
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
				end

				for i = 1, GetNumBuffs(unitTag) do
					local _, startTime, endTime, _, stacks, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo(unitTag, i)
					if settingsTable.hashedAbilityIDs[abilityId] then
                        UniversalTracker.updateVisibility(control, true, settingsTable)

						if stacks == 0 then stacks = "" end
						stackControl:SetText(stacks)
						if settingsTable.overrideTexturePath == "" then
							textureControl:SetTexture(GetAbilityIcon(abilityId))
						else
							textureControl:SetTexture(settingsTable.overrideTexturePath)
						end
						if not IsAbilityPermanent(abilityId) and not UniversalTracker.secretlyPermanent[abilityId] then
                            if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                                endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                            end
                            endTime = endTime*1000
							EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
								local duration = (endTime-GetGameTimeMilliseconds())/1000
								if duration < 0 then
									--Effect Expired
									EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
									if settingsTable.overrideTexturePath == "" then
										textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
									else
										textureControl:SetTexture(settingsTable.overrideTexturePath)
									end
									durationControl:SetText("")
									stackControl:SetText("")
                                    UniversalTracker.updateVisibility(control, false, settingsTable)

								else
									if duration < 2 then
										durationControl:SetText(zo_roundToNearest(duration, 0.1))

									else
										durationControl:SetText(zo_roundToZero(duration))
									end
								end
							end)
						end
						return
					end
				end
				--target doesn't have an effect.
				EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end
				durationControl:SetText("")
				stackControl:SetText("")
                UniversalTracker.updateVisibility(control, false, settingsTable)
			end
		end)
	end
	-- Track internal effects. (Thanks code65536 for making me aware of these)
	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..control:GetName(), EVENT_COMBAT_EVENT, function( _, result, _, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, unitID, abilityID, _)
		if AreUnitsEqual(unitTag, UniversalTracker.unitIDs[unitID]) and
			not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) and
			settingsTable.hashedAbilityIDs[abilityID] then

			-- Only track effects not affected by event_effect_changed
			for i = 1, GetNumBuffs(unitTag) do
				local _, _, _, _, _, _, _, _, _, _, buffID, _, _ = GetUnitBuffInfo(unitTag, i)
				if abilityID == buffID then return end
			end

			if result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION then
                UniversalTracker.updateVisibility(control, true, settingsTable)

				-- Can't get stack information, assume no stacks.
				stackControl:SetText("")

				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(abilityID))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end

                if not IsAbilityPermanent(abilityID) and not UniversalTracker.secretlyPermanent[abilityID] then
                    local endTime
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = GetGameTimeMilliseconds() + (1000*tonumber(settingsTable.textSettings.duration.overrideDuration))
                    else
                        endTime = GetGameTimeMilliseconds() + hitValue
                    end
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                            if settingsTable.overrideTexturePath == "" then
                                textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
                            else
                                textureControl:SetTexture(settingsTable.overrideTexturePath)
                            end
                            durationControl:SetText("")
                            stackControl:SetText("")
                            UniversalTracker.updateVisibility(control, false, settingsTable)
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

	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..control:GetName(), EVENT_EFFECT_CHANGED, function( _, changeType, _, _, tag, startTime, endTime, stackCount, _, _, _, _, _, _, _, abilityID, sourceType)
		if settingsTable.hashedAbilityIDs[abilityID] and
			not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then

			if changeType == EFFECT_RESULT_FADED then
				if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

				--if faded with others running then return.
				for i = 1, GetNumBuffs(unitTag) do
					local _, _, _, _, _, _, _, _, _, _, buffID, _, _ = GetUnitBuffInfo(unitTag, i)
					if settingsTable.hashedAbilityIDs[buffID] and abilityID ~= buffID then return end
				end
			end

			if stackCount == 0 or changeType == EFFECT_RESULT_FADED then stackCount = "" end --stackcount can be 1 instead of 0 after final stone giant cast for example.
			stackControl:SetText(stackCount)
			if settingsTable.overrideTexturePath == "" then
				textureControl:SetTexture(GetAbilityIcon(abilityID))
			else
				textureControl:SetTexture(settingsTable.overrideTexturePath)
			end
			if changeType ~= EFFECT_RESULT_FADED then
                UniversalTracker.updateVisibility(control, true, settingsTable)
                if not IsAbilityPermanent(abilityID) and not UniversalTracker.secretlyPermanent[abilityID] then
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    endTime = endTime * 1000
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                            if settingsTable.overrideTexturePath == "" then
                                textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
                            else
                                textureControl:SetTexture(settingsTable.overrideTexturePath)
                            end
                            durationControl:SetText("")
                            stackControl:SetText("")
                            UniversalTracker.updateVisibility(control, false, settingsTable)
                        else
                            if duration < 2 then
                                durationControl:SetText(zo_roundToNearest(duration, 0.1))
                            else
                                durationControl:SetText(zo_roundToZero(duration))
                            end
                        end
                    end)
                end
			elseif changeType == EFFECT_RESULT_FADED then
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end
				durationControl:SetText("")
				stackControl:SetText("")
                UniversalTracker.updateVisibility(control, false, settingsTable)
			end
		end
	end)
	EVENT_MANAGER:AddFilterForEvent(UniversalTracker.name..control:GetName(), EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, unitTag)
end

function UniversalTracker.InitBar(settingsTable, unitTag, control, animation)

	control:ClearAnchors()
	control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settingsTable.x, settingsTable.y)
	control:SetScale(settingsTable.scale)
	if settingsTable.hideInactive or HUD_FRAGMENT.state == "hidden" then control:SetHidden(true) else control:SetHidden(false) end

	local textureControl = control:GetNamedChild("Texture")
	local barControl = control:GetNamedChild("Bar")
	local abilityNameControl = barControl:GetNamedChild("AbilityName")
	local unitNameControl = barControl:GetNamedChild("UnitName")
	local durationControl = barControl:GetNamedChild("Duration")
    local backgroundControl = barControl:GetNamedChild("Background")

	for i = 1, animation:GetNumAnimations() do
		animation:GetAnimation(i):SetAnimatedControl(barControl)
	end

    durationControl:SetWidth(settingsTable.barSettings.length)
    abilityNameControl:SetWidth(settingsTable.barSettings.length)
    unitNameControl:SetWidth(settingsTable.barSettings.length)
    barControl:SetWidth(settingsTable.barSettings.length)
    backgroundControl:SetWidth(settingsTable.barSettings.length + 2)
    
    if settingsTable.barSettings.alignment == "Left" or settingsTable.barSettings.alignment == "Bottom" then
        barControl:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
        barControl:SetOrientation(ORIENTATION_HORIZONTAL)

        durationControl:ClearAnchors()
        durationControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
        durationControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        
        abilityNameControl:ClearAnchors()
        abilityNameControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
        abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        textureControl:ClearAnchors()
        textureControl:SetAnchor(RIGHT, barControl, LEFT, -1, 0)

        unitNameControl:ClearAnchors()
        unitNameControl:SetAnchor(BOTTOMLEFT, barControl:GetNamedChild("Background"), TOPLEFT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
        unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    elseif settingsTable.barSettings.alignment == "Right" or settingsTable.barSettings.alignment == "Top" then
        barControl:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        barControl:SetOrientation(ORIENTATION_HORIZONTAL)

        durationControl:ClearAnchors()
        durationControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
        durationControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        abilityNameControl:ClearAnchors()
        abilityNameControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
        abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        textureControl:ClearAnchors()
        textureControl:SetAnchor(LEFT, barControl, RIGHT, 1, 0)

        unitNameControl:ClearAnchors()
        unitNameControl:SetAnchor(BOTTOMRIGHT, barControl:GetNamedChild("Background"), TOPRIGHT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
        unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end

    if settingsTable.barSettings.alignment == "Bottom" or settingsTable.barSettings.alignment == "Top" then
        control:SetTransformRotation(0, 0, math.pi/2)
    else
        control:SetTransformRotation(0, 0, 0)
    end
    
    

    local colorAnimation = animation:GetAnimation(1)
    colorAnimation:SetStartColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
    if settingsTable.barSettings.sameEndColor then
        colorAnimation:SetEndColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
    else
        colorAnimation:SetEndColor(settingsTable.barSettings.endColor.r, settingsTable.barSettings.endColor.g, settingsTable.barSettings.endColor.b, settingsTable.barSettings.endColor.a)
    end
    
	colorAnimation:SetHandler("OnPlay", function()
        UniversalTracker.updateVisibility(control, true, settingsTable)
	end)

	colorAnimation:SetHandler("OnStop", function()
        if settingsTable.hideActive then
            if HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) end
        else
            zo_callLater(function()
                if settingsTable.hideInactive and durationControl:GetText() == "0" then
                    control:SetHidden(true)
                end
                UniversalTracker.UpdateListAnchors(settingsTable)
            end, 150)
        end
	end)

    backgroundControl:SetCenterColor(settingsTable.barSettings.backgroundColor.r, settingsTable.barSettings.backgroundColor.g, settingsTable.barSettings.backgroundColor.b, settingsTable.barSettings.backgroundColor.a)
    backgroundControl:SetEdgeColor(settingsTable.barSettings.edgeColor.r, settingsTable.barSettings.edgeColor.g, settingsTable.barSettings.edgeColor.b, settingsTable.barSettings.edgeColor.a)
    

	durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
	durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
	durationControl:SetScale(settingsTable.textSettings.duration.textScale)

	abilityNameControl:SetHidden(settingsTable.textSettings.abilityLabel.hidden)
	abilityNameControl:SetColor(settingsTable.textSettings.abilityLabel.color.r, settingsTable.textSettings.abilityLabel.color.g, settingsTable.textSettings.abilityLabel.color.b, settingsTable.textSettings.abilityLabel.color.a)
	abilityNameControl:SetScale(settingsTable.textSettings.abilityLabel.textScale)
	abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(settingsTable.abilityIDs[1])))

	unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
	unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
	unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
	if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
		unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
	else
		unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
	end

	barControl:SetValue(0)
	durationControl:SetText("0")

	if settingsTable.overrideTexturePath == "" then
		textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
	else
		textureControl:SetTexture(settingsTable.overrideTexturePath)
	end

	-- Start the animation if event has already passed.
	if DoesUnitExist(unitTag) then
		for i = 1, GetNumBuffs(unitTag) do
			local _, startTime, endTime, _, _, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo(unitTag, i)
			if settingsTable.hashedAbilityIDs[abilityId] then
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(abilityId))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end
				abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityId)))
				if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
				else
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
				end
				if tonumber(settingsTable.textSettings.duration.overrideDuration) then
					endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
				end
				for j = 1, animation:GetNumAnimations() do

					animation:GetAnimation(j):SetDuration((endTime - startTime)*1000)
				end
				animation:PlayFromStart(GetGameTimeMilliseconds()-startTime*1000)
				break
			end
		end
	end

	if unitTag == "reticleover" then
		EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..control:GetName(), EVENT_RETICLE_TARGET_CHANGED, function()
			if DoesUnitExist(unitTag) then
				for i = 1, GetNumBuffs(unitTag) do
					local _, startTime, endTime, _, _, _, _, _, _, _, abilityId, _, _ = GetUnitBuffInfo(unitTag, i)
					if settingsTable.hashedAbilityIDs[abilityId] then
						if settingsTable.overrideTexturePath == "" then
							textureControl:SetTexture(GetAbilityIcon(abilityId))
						else
							textureControl:SetTexture(settingsTable.overrideTexturePath)
						end
						abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityId)))
						if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
							unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
						else
							unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
						end
						if tonumber(settingsTable.textSettings.duration.overrideDuration) then
							endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
						end
						for j = 1, animation:GetNumAnimations() do
							animation:GetAnimation(j):SetDuration((endTime - startTime)*1000)
						end
						animation:PlayFromStart(GetGameTimeMilliseconds()-startTime*1000)
						return
					end
				end

				--New target doesn't have the effect.
				if settingsTable.overrideTexturePath == "" then
					textureControl:SetTexture(GetAbilityIcon(next(settingsTable.hashedAbilityIDs)))
				else
					textureControl:SetTexture(settingsTable.overrideTexturePath)
				end
				abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(settingsTable.abilityIDs[1])))
				if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
				else
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
				end
				animation:PlayInstantlyToEnd()

				--Bypass the 150ms wait animation.
                UniversalTracker.updateVisibility(control, false, settingsTable)
			end
		end)
	end

	-- Track internal effects. (Thanks code65536 for making me aware of these)
	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..control:GetName(), EVENT_COMBAT_EVENT, function( _, result, _, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, unitID, abilityID, _)
		if AreUnitsEqual(unitTag, UniversalTracker.unitIDs[unitID]) and
			not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) and
			settingsTable.hashedAbilityIDs[abilityID] then

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
				abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityID)))
				if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
				else
					unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
				end
				for i = 1, animation:GetNumAnimations() do
					if tonumber(settingsTable.textSettings.duration.overrideDuration) then
						animation:GetAnimation(i):SetDuration(1000*tonumber(settingsTable.textSettings.duration.overrideDuration))
					else
						animation:GetAnimation(i):SetDuration(hitValue)
					end
				end
				animation:PlayFromStart()
			end
		end
	end)


	EVENT_MANAGER:RegisterForEvent(UniversalTracker.name.. control:GetName(), EVENT_EFFECT_CHANGED, function(_, changeType, effectSlot, _, tag, startTime, endTime, _, _, _, _, _, _, _, _, abilityID, sourceType)
		if changeType ~= EFFECT_RESULT_FADED and settingsTable.hashedAbilityIDs[abilityID] and not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then
			if settingsTable.overrideTexturePath == "" then
				textureControl:SetTexture(GetAbilityIcon(abilityID))
			else
				textureControl:SetTexture(settingsTable.overrideTexturePath)
			end
			abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityID)))
			if settingsTable.textSettings.unitLabel.accountName and GetUnitDisplayName(unitTag) ~= "" then
				unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitDisplayName(unitTag)))
			else
				unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag)))
			end
			if tonumber(settingsTable.textSettings.duration.overrideDuration) then
				endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
			end
			for i = 1, animation:GetNumAnimations() do
				animation:GetAnimation(i):SetDuration((endTime - startTime)*1000)
			end
			animation:PlayFromStart(GetGameTimeMilliseconds()-startTime*1000)
		end
	end)
	EVENT_MANAGER:AddFilterForEvent(UniversalTracker.name.. control:GetName(), EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, unitTag)
end

function UniversalTracker.InitAll(settingsTable)
    --EVENT_COMBAT_EVENT will handle cleanup on other people applying the buff.
    --EVENT_EFFECT_CHANGED will handle the effect being purged.
    if settingsTable.type == "Compact" then
        EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_COMBAT_EVENT, function(_, result, _, _, _, _, _, sourceType, targetName, _, hitValue, _,  _, _, _, targetUnitId, abilityId, _)
            if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP and not tonumber(settingsTable.textSettings.duration.overrideDuration) then
                --Unit died, remove their tracker.
                local control, controlKey = nil, nil
                if UniversalTracker.targetIDs_Compact[targetUnitId] then
                    for k, v in pairs(UniversalTracker.targetIDs_Compact[targetUnitId]) do
                        if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                            control = UniversalTracker.compactPool:AcquireObject(v.key)
                            controlKey = v.key

                            table.remove(UniversalTracker.targetIDs_Compact[targetUnitId], k)
                            if #UniversalTracker.targetIDs_Compact[targetUnitId] == 0 then UniversalTracker.targetIDs_Compact[targetUnitId] = nil end
                            break
                        end
                    end
                end

                if control and controlKey then
                    EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                    for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                        if v.object == control then
                            table.remove(UniversalTracker.Controls[settingsTable.id], k)
                            break
                        end
                    end
                    UniversalTracker.compactPool:ReleaseObject(controlKey)
                    UniversalTracker.UpdateListAnchors(settingsTable)
                end

            elseif settingsTable.hashedAbilityIDs[abilityId] and hitValue ~= 1 and
                (result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION) then

                if settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET then
                    --Someone else applied the buff. Remove the tracker if one exists.
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                    local control, controlKey = nil, nil
                    if UniversalTracker.targetIDs_Compact[targetUnitId] then
                        for k, v in pairs(UniversalTracker.targetIDs_Compact[targetUnitId]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                control = UniversalTracker.compactPool:AcquireObject(v.key)
                                controlKey = v.key

                                table.remove(UniversalTracker.targetIDs_Compact[targetUnitId], k)
                                if #UniversalTracker.targetIDs_Compact[targetUnitId] == 0 then UniversalTracker.targetIDs_Compact[targetUnitId] = nil end
                                break
                            end
                        end
                    end

                    if control and controlKey then
                        EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                        for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                            if v.object == control then
                                table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                break
                            end
                        end
                        UniversalTracker.compactPool:ReleaseObject(controlKey)
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    end
                else
                    --Look for an existing tracker.
                    local control, controlKey = nil, nil
                    if UniversalTracker.targetIDs_Compact[targetUnitId] then
                        for k, v in pairs(UniversalTracker.targetIDs_Compact[targetUnitId]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                control = UniversalTracker.compactPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if(not control) then
                        --Initialize a new tracker and add it to the list.
                        control, controlKey = UniversalTracker.compactPool:AcquireObject()

                        --Settings
                        --A bit redundant from the Init functions but its made to not use unitTags.
                        control:SetScale(settingsTable.scale)
				        if HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) else control:SetHidden(true) end
                        local textureControl = control:GetNamedChild("Texture")
                        local durationControl = control:GetNamedChild("Duration")
                        local stackControl = control:GetNamedChild("Stacks")
                        local unitNameControl = control:GetNamedChild("UnitName")

                        durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
                        durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
                        durationControl:SetScale(settingsTable.textSettings.duration.textScale)
                        durationControl:ClearAnchors()
                        durationControl:SetAnchor(CENTER, control, CENTER, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                        durationControl:SetText("")

                        --We can't get any stack information from EVENT_COMBAT_EVENT, especially without a unitTag.
                        --It will be handled by EVENT_EFFECT_CHANGED
                        stackControl:SetHidden(settingsTable.textSettings.stacks.hidden)
                        stackControl:SetColor(settingsTable.textSettings.stacks.color.r, settingsTable.textSettings.stacks.color.g, settingsTable.textSettings.stacks.color.b, settingsTable.textSettings.stacks.color.a)
                        stackControl:SetScale(settingsTable.textSettings.stacks.textScale)
                        stackControl:ClearAnchors()
                        stackControl:SetAnchor(TOPRIGHT, control, TOPRIGHT, settingsTable.textSettings.stacks.x - 5, settingsTable.textSettings.stacks.y)

                        unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
                        unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
                        unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
                        unitNameControl:ClearAnchors()
                        unitNameControl:SetAnchor(BOTTOM, control, TOP, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                        unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, targetName))

                        if settingsTable.overrideTexturePath == "" then
                            textureControl:SetTexture(GetAbilityIcon(abilityId))
                        else
                            textureControl:SetTexture(settingsTable.overrideTexturePath)
                        end

                        --Update tables
                        if(not UniversalTracker.targetIDs_Compact[targetUnitId]) then UniversalTracker.targetIDs_Compact[targetUnitId] = {} end
                        table.insert(UniversalTracker.targetIDs_Compact[targetUnitId], {key = controlKey, trackerID = settingsTable.id, abilityID = abilityId})

                        table.insert(UniversalTracker.Controls[settingsTable.id], {object = control, key = controlKey, unitTag = "reticleover"})
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    else
                        if settingsTable.overrideTexturePath == "" then
                            control:GetNamedChild("Texture"):SetTexture(GetAbilityIcon(abilityId))
                        else
                            control:GetNamedChild("Texture"):SetTexture(settingsTable.overrideTexturePath)
                        end
                    end

                    local endTime
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = GetGameTimeMilliseconds() + 1000*tonumber(settingsTable.textSettings.duration.overrideDuration)
                    else
                        endTime = GetGameTimeMilliseconds() + hitValue
                    end
                    local durationControl = control:GetNamedChild("Duration")
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            durationControl:SetText("")
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                            if durationControl:GetText() == "" then
                                --Try to release objects.
                                --Objects might already have been released if someone else reapplied the buff early.
                                if not UniversalTracker.targetIDs_Compact[targetUnitId] then return end

                                for k, v in pairs(UniversalTracker.targetIDs_Compact[targetUnitId]) do
                                    if v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                        table.remove(UniversalTracker.targetIDs_Compact[targetUnitId], k)
                                        if #UniversalTracker.targetIDs_Compact[targetUnitId] == 0 then UniversalTracker.targetIDs_Compact[targetUnitId] = nil end
                                        break
                                    end
                                end
                                for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                                    if v.object == control then
                                        controlKey = v.key
                                        table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                        break
                                    end
                                end
                                UniversalTracker.compactPool:ReleaseObject(controlKey)
                                UniversalTracker.UpdateListAnchors(settingsTable)
                            end
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
        end)

        EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_EFFECT_CHANGED, function( _, changeType, _, _, tag, startTime, endTime, stackCount, _, _, _, _, _, unitName, unitID, abilityID, sourceType)
            if settingsTable.hashedAbilityIDs[abilityID] then
                if changeType == EFFECT_RESULT_FADED then
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                    --Effect cleansed early.
                    local control, controlKey = nil, nil
                    if UniversalTracker.targetIDs_Compact[unitID] then
                        for k, v in pairs(UniversalTracker.targetIDs_Compact[unitID]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                control = UniversalTracker.compactPool:AcquireObject(v.key)
                                controlKey = v.key

                                table.remove(UniversalTracker.targetIDs_Compact[unitID], k)
                                if #UniversalTracker.targetIDs_Compact[unitID] == 0 then UniversalTracker.targetIDs_Compact[unitID] = nil end
                                break
                            end
                        end
                    end

                    if control and controlKey then
                        EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                        for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                            if v.object == control then
                                table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                break
                            end
                        end
                        UniversalTracker.compactPool:ReleaseObject(controlKey)
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    end
                elseif not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then
                    --Look for an existing tracker.
                    local control, controlKey = nil, nil
                    if UniversalTracker.targetIDs_Compact[unitID] then
                        for k, v in pairs(UniversalTracker.targetIDs_Compact[unitID]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                control = UniversalTracker.compactPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if(not control) then
                        --Initialize a new tracker and add it to the list.
                        control, controlKey = UniversalTracker.compactPool:AcquireObject()

                        --Settings
                        --A bit redundant from the Init functions but its made to not use unitTags.
                        control:SetScale(settingsTable.scale)
				        if HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) else control:SetHidden(true) end
                        local textureControl = control:GetNamedChild("Texture")
                        local durationControl = control:GetNamedChild("Duration")
                        local stackControl = control:GetNamedChild("Stacks")
                        local unitNameControl = control:GetNamedChild("UnitName")

                        durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
                        durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
                        durationControl:SetScale(settingsTable.textSettings.duration.textScale)
                        durationControl:ClearAnchors()
                        durationControl:SetAnchor(CENTER, control, CENTER, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                        durationControl:SetText("")

                        stackControl:SetHidden(settingsTable.textSettings.stacks.hidden)
                        stackControl:SetColor(settingsTable.textSettings.stacks.color.r, settingsTable.textSettings.stacks.color.g, settingsTable.textSettings.stacks.color.b, settingsTable.textSettings.stacks.color.a)
                        stackControl:SetScale(settingsTable.textSettings.stacks.textScale)
                        stackControl:ClearAnchors()
                        stackControl:SetAnchor(TOPRIGHT, control, TOPRIGHT, settingsTable.textSettings.stacks.x - 5, settingsTable.textSettings.stacks.y)
                        if stackCount > 0 then stackControl:SetText(tostring(stackCount)) else stackControl:SetText("") end

                        unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
                        unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
                        unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
                        unitNameControl:ClearAnchors()
                        unitNameControl:SetAnchor(BOTTOM, control, TOP, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                        unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, unitName))

                        if settingsTable.overrideTexturePath == "" then
                            textureControl:SetTexture(GetAbilityIcon(abilityId))
                        else
                            textureControl:SetTexture(settingsTable.overrideTexturePath)
                        end

                        --Update tables
                        if(not UniversalTracker.targetIDs_Compact[unitID]) then UniversalTracker.targetIDs_Compact[unitID] = {} end
                        table.insert(UniversalTracker.targetIDs_Compact[unitID], {key = controlKey, trackerID = settingsTable.id, abilityID = abilityID})

                        table.insert(UniversalTracker.Controls[settingsTable.id], {object = control, key = controlKey, unitTag = "reticleover"})
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    else
                        if settingsTable.overrideTexturePath == "" then
                            control:GetNamedChild("Texture"):SetTexture(GetAbilityIcon(abilityID))
                        else
                            control:GetNamedChild("Texture"):SetTexture(settingsTable.overrideTexturePath)
                        end
                        if stackCount > 0 then control:GetNamedChild("Stacks"):SetText(tostring(stackCount)) else control:GetNamedChild("Stacks"):SetText("") end
                    end

                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    endTime = endTime * 1000

                    local durationControl = control:GetNamedChild("Duration")
                    local stackControl = control:GetNamedChild("Stacks")
                    EVENT_MANAGER:RegisterForUpdate(UniversalTracker.name..control:GetName(), 100, function()
                        local duration = (endTime-GetGameTimeMilliseconds())/1000
                        if duration < 0 then
                            --Effect Expired
                            durationControl:SetText("")
                            stackControl:SetText("")
                            EVENT_MANAGER:UnregisterForUpdate(UniversalTracker.name..control:GetName())
                            zo_callLater(function()
                                if durationControl:GetText() == "" then
                                    --Try to release objects.
                                    --Objects might already have been released if someone else reapplied the buff early.
                                    if not UniversalTracker.targetIDs_Compact[unitID] then return end

                                    for k, v in pairs(UniversalTracker.targetIDs_Compact[unitID]) do
                                        if v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                            table.remove(UniversalTracker.targetIDs_Compact[unitID], k)
                                            if #UniversalTracker.targetIDs_Compact[unitID] == 0 then UniversalTracker.targetIDs_Compact[unitID] = nil end
                                            break
                                        end
                                    end
                                    for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                                        if v.object == control then
                                            controlKey = v.key
                                            table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                            break
                                        end
                                    end
                                    UniversalTracker.compactPool:ReleaseObject(controlKey)
                                    UniversalTracker.UpdateListAnchors(settingsTable)
                                end
                            end, 150)
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
        end)
    elseif settingsTable.type == "Bar" then
        EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_COMBAT_EVENT, function(_, result, _, _, _, _, _, sourceType, targetName, _, hitValue, _,  _, _, _, targetUnitId, abilityId, _)
            if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP then
                if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                --Unit died, remove their tracker.
                local animation = nil
                if UniversalTracker.targetIDs_BarAnimation[targetUnitId] then
                    for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[targetUnitId]) do
                        if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                            animation = UniversalTracker.barAnimationPool:AcquireObject(v.key)
                            break
                        end
                    end
                end

                if animation then animation:PlayInstantlyToEnd() end

            elseif settingsTable.hashedAbilityIDs[abilityId] and hitValue ~= 1 and
                (result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION) then

                if (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then
                    --Someone else applied the buff. 
                    --Remove the tracker by playing the animation instantly to end and letting the onStop function do cleanup.

                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                    local animation = nil
                    if UniversalTracker.targetIDs_BarAnimation[targetUnitId] then
                        for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[targetUnitId]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                animation = UniversalTracker.barAnimationPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if animation then animation:PlayInstantlyToEnd() end
                else
                    --Look for an existing tracker.
                    local control, controlKey, animation, animationKey = nil, nil, nil, nil
                    if UniversalTracker.targetIDs_Bar[targetUnitId] then
                        for k, v in pairs(UniversalTracker.targetIDs_Bar[targetUnitId]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                control = UniversalTracker.barPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end
                    if UniversalTracker.targetIDs_BarAnimation[targetUnitId] then
                        for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[targetUnitId]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                animation = UniversalTracker.barAnimationPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if(not control or not animation) then
                        --Initialize a new tracker and add it to the list.
                        control, controlKey = UniversalTracker.barPool:AcquireObject()
                        animation, animationKey = UniversalTracker.barAnimationPool:AcquireObject()

                        --Settings
                        --A bit redundant from the Init functions but its made to not use unitTags.
                        control:SetScale(settingsTable.scale)
				        if HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) else control:SetHidden(true) end

                        local textureControl = control:GetNamedChild("Texture")
                        local barControl = control:GetNamedChild("Bar")
                        local abilityNameControl = barControl:GetNamedChild("AbilityName")
                        local unitNameControl = barControl:GetNamedChild("UnitName")
                        local durationControl = barControl:GetNamedChild("Duration")
                        local backgroundControl = barControl:GetNamedChild("Background")

                        for i = 1, animation:GetNumAnimations() do
                            animation:GetAnimation(i):SetAnimatedControl(barControl)
                        end
                                            
                        durationControl:SetWidth(settingsTable.barSettings.length)
                        abilityNameControl:SetWidth(settingsTable.barSettings.length)
                        unitNameControl:SetWidth(settingsTable.barSettings.length)
                        barControl:SetWidth(settingsTable.barSettings.length)
                        backgroundControl:SetWidth(settingsTable.barSettings.length + 2)

                        if settingsTable.barSettings.alignment == "Left" or settingsTable.barSettings.alignment == "Bottom" then
                            barControl:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
                            barControl:SetOrientation(ORIENTATION_HORIZONTAL)

                            durationControl:ClearAnchors()
                            durationControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                            durationControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                            
                            abilityNameControl:ClearAnchors()
                            abilityNameControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
                            abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

                            textureControl:ClearAnchors()
                            textureControl:SetAnchor(RIGHT, barControl, LEFT, -1, 0)

                            unitNameControl:ClearAnchors()
                            unitNameControl:SetAnchor(BOTTOMLEFT, barControl:GetNamedChild("Background"), TOPLEFT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                            unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                        elseif settingsTable.barSettings.alignment == "Right" or settingsTable.barSettings.alignment == "Top" then
                            barControl:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
                            barControl:SetOrientation(ORIENTATION_HORIZONTAL)

                            durationControl:ClearAnchors()
                            durationControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                            durationControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

                            abilityNameControl:ClearAnchors()
                            abilityNameControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
                            abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

                            textureControl:ClearAnchors()
                            textureControl:SetAnchor(LEFT, barControl, RIGHT, 1, 0)

                            unitNameControl:ClearAnchors()
                            unitNameControl:SetAnchor(BOTTOMRIGHT, barControl:GetNamedChild("Background"), TOPRIGHT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                            unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                        end
                        
                        if settingsTable.barSettings.alignment == "Bottom" or settingsTable.barSettings.alignment == "Top" then
                            control:SetTransformRotation(0, 0, math.pi/2)
                        else
                            control:SetTransformRotation(0, 0, 0)
                        end

                        local colorAnimation = animation:GetAnimation(1)
                        colorAnimation:SetStartColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
                        if settingsTable.barSettings.sameEndColor then
                            colorAnimation:SetEndColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
                        else
                            colorAnimation:SetEndColor(settingsTable.barSettings.endColor.r, settingsTable.barSettings.endColor.g, settingsTable.barSettings.endColor.b, settingsTable.barSettings.endColor.a)
                        end

                        durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
                        durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
                        durationControl:SetScale(settingsTable.textSettings.duration.textScale)

                        abilityNameControl:SetHidden(settingsTable.textSettings.abilityLabel.hidden)
                        abilityNameControl:SetColor(settingsTable.textSettings.abilityLabel.color.r, settingsTable.textSettings.abilityLabel.color.g, settingsTable.textSettings.abilityLabel.color.b, settingsTable.textSettings.abilityLabel.color.a)
                        abilityNameControl:SetScale(settingsTable.textSettings.abilityLabel.textScale)
                        abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityId)))

                        unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
                        unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
                        unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
                        unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, targetName))

                        barControl:SetValue(0)
                        durationControl:SetText("0")

                        if settingsTable.overrideTexturePath == "" then
                            textureControl:SetTexture(GetAbilityIcon(abilityId))
                        else
                            textureControl:SetTexture(settingsTable.overrideTexturePath)
                        end

                        --Update tables
                        if(not UniversalTracker.targetIDs_BarAnimation[targetUnitId]) then UniversalTracker.targetIDs_BarAnimation[targetUnitId] = {} end
                        if(not UniversalTracker.targetIDs_Bar[targetUnitId]) then UniversalTracker.targetIDs_Bar[targetUnitId] = {} end
                        table.insert(UniversalTracker.targetIDs_BarAnimation[targetUnitId], {key = animationKey, trackerID = settingsTable.id, abilityID = abilityId})
                        table.insert(UniversalTracker.targetIDs_Bar[targetUnitId], {key = controlKey, trackerID = settingsTable.id, abilityID = abilityId})

                        table.insert(UniversalTracker.Animations[settingsTable.id], {object = animation, key = animationKey})
                        table.insert(UniversalTracker.Controls[settingsTable.id], {object = control, key = controlKey, unitTag = "reticleover"})
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    else
                        control:GetNamedChild("Bar"):GetNamedChild("AbilityName"):SetText(GetAbilityName(abilityId))
                        if settingsTable.overrideTexturePath == "" then
                            control:GetNamedChild("Texture"):SetTexture(GetAbilityIcon(abilityId))
                        else
                            control:GetNamedChild("Texture"):SetTexture(settingsTable.overrideTexturePath)
                        end
                    end

                    --Remove from list if it is still inactive
                    animation:GetAnimation(1):SetHandler("OnStop", function()
                        if control:GetNamedChild("Bar"):GetNamedChild("Duration"):GetText() == "0" then
                            --Try to release objects.
                            if not UniversalTracker.targetIDs_BarAnimation[targetUnitId] then return end

                            for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[targetUnitId]) do
                                if v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                    animationKey = v.key
                                    table.remove(UniversalTracker.targetIDs_BarAnimation[targetUnitId], k)
                                    if #UniversalTracker.targetIDs_BarAnimation[targetUnitId] == 0 then UniversalTracker.targetIDs_BarAnimation[targetUnitId] = nil end
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.targetIDs_Bar[targetUnitId]) do
                                if v.trackerID == settingsTable.id and v.abilityID == abilityId then
                                    controlKey = v.key
                                    table.remove(UniversalTracker.targetIDs_Bar[targetUnitId], k)
                                    if #UniversalTracker.targetIDs_Bar[targetUnitId] == 0 then UniversalTracker.targetIDs_Bar[targetUnitId] = nil end
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.Animations[settingsTable.id]) do
                                if v.object == animation then
                                    table.remove(UniversalTracker.Animations[settingsTable.id], k)
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                                if v.object == control then
                                    table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                    break
                                end
                            end
                            UniversalTracker.barPool:ReleaseObject(controlKey)
                            UniversalTracker.barAnimationPool:ReleaseObject(animationKey)
                            UniversalTracker.UpdateListAnchors(settingsTable)
                        end
                    end)

                    --Start countdown animation
                    for i = 1, animation:GetNumAnimations() do
                        if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                            animation:GetAnimation(i):SetDuration(1000*tonumber(settingsTable.textSettings.duration.overrideDuration))
                        else
                            animation:GetAnimation(i):SetDuration(hitValue)
                        end
                    end
                    animation:PlayFromStart()
                end
            end
        end)

        EVENT_MANAGER:RegisterForEvent(UniversalTracker.name..settingsTable.id, EVENT_EFFECT_CHANGED, function( _, changeType, _, _, tag, startTime, endTime, stackCount, _, _, _, _, _, unitName, unitID, abilityID, sourceType)
            if settingsTable.hashedAbilityIDs[abilityID] then
                if changeType == EFFECT_RESULT_FADED then
                    --Effect got cleansed early.
                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then return end

                    local animation = nil
                    if UniversalTracker.targetIDs_BarAnimation[unitID] then
                        for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[unitID]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                animation = UniversalTracker.barAnimationPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if animation then animation:PlayInstantlyToEnd() end
                elseif not (settingsTable.appliedBySelf and sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET) then

                    --Look for an existing tracker.
                    local control, controlKey, animation, animationKey = nil, nil, nil, nil
                    if UniversalTracker.targetIDs_Bar[unitID] then
                        for k, v in pairs(UniversalTracker.targetIDs_Bar[unitID]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                control = UniversalTracker.barPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end
                    if UniversalTracker.targetIDs_BarAnimation[unitID] then
                        for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[unitID]) do
                            if v and v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                animation = UniversalTracker.barAnimationPool:AcquireObject(v.key)
                                break
                            end
                        end
                    end

                    if(not control or not animation) then
                        --Initialize a new tracker and add it to the list.
                        control, controlKey = UniversalTracker.barPool:AcquireObject()
                        animation, animationKey = UniversalTracker.barAnimationPool:AcquireObject()

                        --Settings
                        --A bit redundant from the Init functions but its made to not rely on unitTags.
                        control:SetScale(settingsTable.scale)
				        if HUD_FRAGMENT.state ~= "hidden" then control:SetHidden(false) else control:SetHidden(true) end

                        local textureControl = control:GetNamedChild("Texture")
                        local barControl = control:GetNamedChild("Bar")
                        local abilityNameControl = barControl:GetNamedChild("AbilityName")
                        local unitNameControl = barControl:GetNamedChild("UnitName")
                        local durationControl = barControl:GetNamedChild("Duration")
                        local backgroundControl = barControl:GetNamedChild("Background")

                        durationControl:SetWidth(settingsTable.barSettings.length)
                        abilityNameControl:SetWidth(settingsTable.barSettings.length)
                        unitNameControl:SetWidth(settingsTable.barSettings.length)
                        barControl:SetWidth(settingsTable.barSettings.length)
                        backgroundControl:SetWidth(settingsTable.barSettings.length + 2)

                        if settingsTable.barSettings.alignment == "Left" or settingsTable.barSettings.alignment == "Bottom" then
                            barControl:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
                            barControl:SetOrientation(ORIENTATION_HORIZONTAL)

                            durationControl:ClearAnchors()
                            durationControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                            durationControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                            
                            abilityNameControl:ClearAnchors()
                            abilityNameControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
                            abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

                            textureControl:ClearAnchors()
                            textureControl:SetAnchor(RIGHT, barControl, LEFT, -1, 0)

                            unitNameControl:ClearAnchors()
                            unitNameControl:SetAnchor(BOTTOMLEFT, barControl:GetNamedChild("Background"), TOPLEFT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                            unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                        elseif settingsTable.barSettings.alignment == "Right" or settingsTable.barSettings.alignment == "Top" then
                            barControl:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
                            barControl:SetOrientation(ORIENTATION_HORIZONTAL)

                            durationControl:ClearAnchors()
                            durationControl:SetAnchor(LEFT, barControl:GetNamedChild("Background"), LEFT, settingsTable.textSettings.duration.x, settingsTable.textSettings.duration.y)
                            durationControl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

                            abilityNameControl:ClearAnchors()
                            abilityNameControl:SetAnchor(RIGHT, barControl:GetNamedChild("Background"), RIGHT, settingsTable.textSettings.abilityLabel.x, settingsTable.textSettings.abilityLabel.y)
                            abilityNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

                            textureControl:ClearAnchors()
                            textureControl:SetAnchor(LEFT, barControl, RIGHT, 1, 0)

                            unitNameControl:ClearAnchors()
                            unitNameControl:SetAnchor(BOTTOMRIGHT, barControl:GetNamedChild("Background"), TOPRIGHT, settingsTable.textSettings.unitLabel.x, settingsTable.textSettings.unitLabel.y)
                            unitNameControl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                        end
                        
                        if settingsTable.barSettings.alignment == "Bottom" or settingsTable.barSettings.alignment == "Top" then
                            control:SetTransformRotation(0, 0, math.pi/2)
                        else
                            control:SetTransformRotation(0, 0, 0)
                        end

                        local colorAnimation = animation:GetAnimation(1)
                        colorAnimation:SetStartColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
                        if settingsTable.barSettings.sameEndColor then
                            colorAnimation:SetEndColor(settingsTable.barSettings.startColor.r, settingsTable.barSettings.startColor.g, settingsTable.barSettings.startColor.b, settingsTable.barSettings.startColor.a)
                        else
                            colorAnimation:SetEndColor(settingsTable.barSettings.endColor.r, settingsTable.barSettings.endColor.g, settingsTable.barSettings.endColor.b, settingsTable.barSettings.endColor.a)
                        end

                        backgroundControl:SetCenterColor(settingsTable.barSettings.backgroundColor.r, settingsTable.barSettings.backgroundColor.g, settingsTable.barSettings.backgroundColor.b, settingsTable.barSettings.backgroundColor.a)
                        backgroundControl:SetEdgeColor(settingsTable.barSettings.edgeColor.r, settingsTable.barSettings.edgeColor.g, settingsTable.barSettings.edgeColor.b, settingsTable.barSettings.edgeColor.a)
    

                        for i = 1, animation:GetNumAnimations() do
                            animation:GetAnimation(i):SetAnimatedControl(barControl)
                        end

                        durationControl:SetHidden(settingsTable.textSettings.duration.hidden)
                        durationControl:SetColor(settingsTable.textSettings.duration.color.r, settingsTable.textSettings.duration.color.g, settingsTable.textSettings.duration.color.b, settingsTable.textSettings.duration.color.a)
                        durationControl:SetScale(settingsTable.textSettings.duration.textScale)
                        
                        abilityNameControl:SetHidden(settingsTable.textSettings.abilityLabel.hidden)
                        abilityNameControl:SetColor(settingsTable.textSettings.abilityLabel.color.r, settingsTable.textSettings.abilityLabel.color.g, settingsTable.textSettings.abilityLabel.color.b, settingsTable.textSettings.abilityLabel.color.a)
                        abilityNameControl:SetScale(settingsTable.textSettings.abilityLabel.textScale)
                        abilityNameControl:SetText(zo_strformat(SI_UNIT_NAME, GetAbilityName(abilityID)))

                        unitNameControl:SetHidden(settingsTable.textSettings.unitLabel.hidden)
                        unitNameControl:SetColor(settingsTable.textSettings.unitLabel.color.r, settingsTable.textSettings.unitLabel.color.g, settingsTable.textSettings.unitLabel.color.b, settingsTable.textSettings.unitLabel.color.a)
                        unitNameControl:SetScale(settingsTable.textSettings.unitLabel.textScale)
                        unitNameControl:SetText(zo_strformat(SI_UNIT_NAME, unitName))

                        barControl:SetValue(0)
                        durationControl:SetText("0")

                        if settingsTable.overrideTexturePath == "" then
                            textureControl:SetTexture(GetAbilityIcon(abilityID))
                        else
                            textureControl:SetTexture(settingsTable.overrideTexturePath)
                        end

                        --Update tables
                        if(not UniversalTracker.targetIDs_BarAnimation[unitID]) then UniversalTracker.targetIDs_BarAnimation[unitID] = {} end
                        if(not UniversalTracker.targetIDs_Bar[unitID]) then UniversalTracker.targetIDs_Bar[unitID] = {} end
                        table.insert(UniversalTracker.targetIDs_BarAnimation[unitID], {key = animationKey, trackerID = settingsTable.id, abilityID = abilityID})
                        table.insert(UniversalTracker.targetIDs_Bar[unitID], {key = controlKey, trackerID = settingsTable.id, abilityID = abilityID})

                        table.insert(UniversalTracker.Animations[settingsTable.id], {object = animation, key = animationKey})
                        table.insert(UniversalTracker.Controls[settingsTable.id], {object = control, key = controlKey, unitTag = "reticleover"})
                        UniversalTracker.UpdateListAnchors(settingsTable)
                    else
                        control:GetNamedChild("Bar"):GetNamedChild("AbilityName"):SetText(GetAbilityName(abilityID))
                        if settingsTable.overrideTexturePath == "" then
                            control:GetNamedChild("Texture"):SetTexture(GetAbilityIcon(abilityID))
                        else
                            control:GetNamedChild("Texture"):SetTexture(settingsTable.overrideTexturePath)
                        end
                    end

                    --Remove from list if it is still inactive
                    animation:GetAnimation(1):SetHandler("OnStop", function()
                        if control:GetNamedChild("Bar"):GetNamedChild("Duration"):GetText() == "0" then
                            --Try to release objects.
                            --Objects might already have been released if someone else reapplied the buff early.
                            if not UniversalTracker.targetIDs_BarAnimation[unitID] then return end

                            for k, v in pairs(UniversalTracker.targetIDs_BarAnimation[unitID]) do
                                if v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                    animationKey = v.key
                                    table.remove(UniversalTracker.targetIDs_BarAnimation[unitID], k)
                                    if #UniversalTracker.targetIDs_BarAnimation[unitID] == 0 then UniversalTracker.targetIDs_BarAnimation[unitID] = nil end
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.targetIDs_Bar[unitID]) do
                                if v.trackerID == settingsTable.id and v.abilityID == abilityID then
                                    controlKey = v.key
                                    table.remove(UniversalTracker.targetIDs_Bar[unitID], k)
                                    if #UniversalTracker.targetIDs_Bar[unitID] == 0 then UniversalTracker.targetIDs_Bar[unitID] = nil end
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.Animations[settingsTable.id]) do
                                if v.object == animation then
                                    table.remove(UniversalTracker.Animations[settingsTable.id], k)
                                    break
                                end
                            end
                            for k, v in pairs(UniversalTracker.Controls[settingsTable.id]) do
                                if v.object == control then
                                    table.remove(UniversalTracker.Controls[settingsTable.id], k)
                                    break
                                end
                            end
                            UniversalTracker.barPool:ReleaseObject(controlKey)
                            UniversalTracker.barAnimationPool:ReleaseObject(animationKey)
                            UniversalTracker.UpdateListAnchors(settingsTable)
                        end
                    end)

                    if tonumber(settingsTable.textSettings.duration.overrideDuration) then
                        endTime = startTime + tonumber(settingsTable.textSettings.duration.overrideDuration)
                    end
                    --Start countdown animation
                    for i = 1, animation:GetNumAnimations() do
                        animation:GetAnimation(i):SetDuration((endTime - startTime)*1000)
                    end
                    animation:PlayFromStart()
                end
            end
        end)
    end
end