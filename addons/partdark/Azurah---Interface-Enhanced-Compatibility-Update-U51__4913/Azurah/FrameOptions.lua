local Azurah	= _G['Azurah'] -- grab addon table from global

-- UPVALUES --
local AZ_POWERTYPE_MOUNT_STAMINA = COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA

local userData


local function CheckOptions1(frame) -- special cases for modified frames from Unlock.lua (Phinix)
	
	if (frame == 'ZO_PlayerAttributeMountStamina') then -- gamepad mod doesn't anchor mount bar (Phinix)
		if (IsInGamepadPreferredMode()) then
			ZO_PlayerAttributeMountStamina:ClearAnchors()
			ZO_PlayerAttributeMountStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeStamina, BOTTOMLEFT, 0, 0)
		end
	end
	
	if (frame == 'ZO_PlayerAttributeWerewolf') then -- gamepad mod doesn't anchor ww bar (Phinix)
		if (IsInGamepadPreferredMode()) then
			ZO_PlayerAttributeWerewolf:ClearAnchors()
			ZO_PlayerAttributeWerewolf:SetAnchor(TOPRIGHT, ZO_PlayerAttributeMagicka, BOTTOMRIGHT, 0, 0)
		end
	end
	
	if (frame == 'ZO_Subtitles') then -- Fix scaled subtitle background alignment (Phinix)
		local scale = userData[frame].scale
		local bgLeft = _G["ZO_SubtitlesTextBackgroundLeft"]
		local bgRight = _G["ZO_SubtitlesTextBackgroundRight"]
	
		bgLeft:SetDimensionConstraints(0, 0, 64 * scale, 0)
		bgRight:SetDimensionConstraints(0, 0, 64 * scale, 0)
		bgLeft:SetWidth(64 * scale)
		bgRight:SetWidth(64 * scale)
	end
	
	if (frame == 'ZO_CompassFrame') then
		AZ_MOVED_COMPASS = true	-- GLOBALS FOR WYKKYD
	end
	
	if (frame == 'ZO_TargetUnitFramereticleover') then
		AZ_MOVED_TARGET = true	-- GLOBALS FOR WYKKYD
	end
	
	if (frame == 'ZO_ActionBar1' and userData[frame].scale ~= 1) then -- scale of action bar is not the default, replace ActionButton.ApplySwapAnimationStyle with our own
		ActionButton.ApplySwapAnimationStyle = Azurah.ApplySwapAnimationStyle
	end
end

local function CheckOptions2(frame) -- special cases for unmodified frames from Unlock.lua (Phinix)
	local obj = _G[frame]
	-- Needs updating after adjusting the dimensions when it hasn't been moved before
	if frame == "ZO_ActiveCombatTips" then
		obj:ClearAnchors()
		obj:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	-- No saved variable data but position/scale changed, reset based on temp values (Phinix)
	elseif Azurah.uiNoData and Azurah.uiNoData[frame] then
		local nFrame = Azurah.uiNoData[frame]
		obj:ClearAnchors()
		obj:SetAnchor(nFrame.nPoint, GuiRoot, nFrame.nPoint, nFrame.nX, nFrame.nY)
		obj:SetScale(1)
	end
end

local function CheckIsGroupFrame(cFrame)
	if (cFrame == 'ZO_SmallGroupAnchorFrame') or (cFrame == 'ZO_LargeGroupAnchorFrame1') or (cFrame == 'ZO_LargeGroupAnchorFrame2') or (cFrame == 'ZO_LargeGroupAnchorFrame3') or (cFrame == 'ZO_LargeGroupAnchorFrame4') or (cFrame == 'ZO_LargeGroupAnchorFrame5') or (cFrame == 'ZO_LargeGroupAnchorFrame6') then
		return true
	else
		return false
	end
end


-- ------------------------------------
-- GLOBAL FRAME CONFIGURATION (Phinix)
-- ------------------------------------
function Azurah:UpdateFrameOptions(frame)
	local globalOpacityOn = Azurah.db.globalOpacityOn

	local function ProcessFrame(frame, opacityMod)
		
		if userData[frame] then
			local control = GetControl(frame)
			if control then
				control:ClearAnchors()
				control:SetAnchor(userData[frame].point, GuiRoot, userData[frame].point, userData[frame].x, userData[frame].y)
				control:SetScale(userData[frame].scale)

				if frame == "ZO_ActionBar1" then
					local state = ((IsUnitInCombat('player')) or (Azurah.db.globalOpacityOn)) and true or false
					Azurah:UpdateAttributeFade(state, false)
				elseif frame ~= "ZO_PlayerAttributeHealth" and frame ~= "ZO_PlayerAttributeMagicka" and frame ~= "ZO_PlayerAttributeStamina" then
					if (globalOpacityOn) then
						control:SetAlpha(1)
					elseif opacityMod ~= nil then
						control:SetAlpha(opacityMod)
					else
						if (IsUnitInCombat("player")) then -- set frame opacity based on settings and combat state (Phinix)
							if userData[frame].altcombat and userData[frame].altcombat == true then
								if userData[frame].copacity then
									control:SetAlpha( userData[frame].copacity )
									if CheckIsGroupFrame(frame) then GetControl('ZO_UnitFramesGroups'):SetAlpha( userData[frame].copacity ) end
								end
							else
								if userData[frame].opacity then
									control:SetAlpha( userData[frame].opacity )
									if CheckIsGroupFrame(frame) then GetControl('ZO_UnitFramesGroups'):SetAlpha( userData[frame].opacity ) end
								end
							end
						else
							if userData[frame].opacity then
								control:SetAlpha( userData[frame].opacity )
								if CheckIsGroupFrame(frame) then GetControl('ZO_UnitFramesGroups'):SetAlpha( userData[frame].opacity ) end
							end
						end
					end
				end
			end
			CheckOptions1(frame)
		else
			CheckOptions2(frame)
		end
	end

	local function ConfigureExceptions(frame)

		if frame == "ZO_CompassFrame" then
			Azurah:InitializeCompass(true)

		elseif frame == "Azurah_GroupFrames" then
			ProcessFrame('ZO_SmallGroupAnchorFrame')
			ProcessFrame('ZO_LargeGroupAnchorFrame1')
			ProcessFrame('ZO_LargeGroupAnchorFrame2')
			ProcessFrame('ZO_LargeGroupAnchorFrame3')
			ProcessFrame('ZO_LargeGroupAnchorFrame4')
			ProcessFrame('ZO_LargeGroupAnchorFrame5')
			ProcessFrame('ZO_LargeGroupAnchorFrame6')

		elseif frame == "ZO_ActiveCombatTipsTip" then -- set combat tips to initially hidden to avoid white pixel showing (Phinix)
			ProcessFrame(frame, 0)

		elseif frame == "ZO_PlayerAttributeMountStamina" then -- treat mount stamina like player resource bars (Phinix)
			local optionState = tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_RESOURCE_BARS))
			if optionState == RESOURCE_BARS_SETTING_CHOICE_DONT_SHOW then
				ProcessFrame(frame, 0)
			elseif optionState == RESOURCE_BARS_SETTING_CHOICE_AUTOMATIC then
				local rCur, rMax, eMax = GetUnitPower('player', AZ_POWERTYPE_MOUNT_STAMINA)
				if rCur < eMax then
					ProcessFrame(frame, 1)
				else
					ProcessFrame(frame)
				end
			else
				ProcessFrame(frame)
			end

	--	elseif -- future exceptions will go here (Phinix)

		else
			ProcessFrame(frame)
		end
	end

	if not IsInGamepadPreferredMode() then
		userData = (self.db.uiData.keyboard) and self.db.uiData.keyboard or {}
	else
		userData = (self.db.uiData.gamepad) and self.db.uiData.gamepad or {}
	end
	if frame then
		ConfigureExceptions(frame)
	else
		for k, v in pairs(userData) do
			ConfigureExceptions(k)
		end
	end
end
