local textures={
{"worldmap","worldmap_frame_edge.dds"},
--Action bar
{"actionbar","abilityframe64_down.dds"},
{"actionbar","abilityframe64_up.dds"},
--Target bar
{"unitattributevisualizer","targetbar_dynamic_frame.dds"},
{"unitframes","target_name_bracket_left.dds"},
{"unitframes","target_name_bracket_right.dds"},
{"unitframes","targetunitframe_bracket_level2_left.dds"},
{"unitframes","targetunitframe_bracket_level2_right.dds"},
{"unitframes","targetunitframe_bracket_level3_left.dds"},
{"unitframes","targetunitframe_bracket_level3_right.dds"},
{"unitframes","targetunitframe_bracket_level4_left.dds"},
{"unitframes","targetunitframe_bracket_level4_right.dds"},
--Player exp bar
{"miscellaneous","progressbar_frame.dds"},
--Player attributes bars
{"unitattributevisualizer","attributebar_dynamic_frame.dds"},
{"unitattributevisualizer","attributebar_small_frame.dds"},
{"unitattributevisualizer","attributebar_small_frame_center.dds"},
--Compass
{"compass","compass.dds"},
{"bossbar","bossbar_bracket_left.dds"},
{"bossbar","bossbar_bracket_right.dds"},
}
local flat={
--Target bar
{"unitattributevisualizer","targetbar_dynamic_invulnerable.dds"},
{"unitattributevisualizer","targetbar_dynamic_fill_gloss.dds"},
{"unitattributevisualizer","targetbar_dynamic_leadingedge_gloss.dds"},
--Player exp bar
{"miscellaneous","progressbar_genericfill_gloss.dds"},
{"miscellaneous","progressbar_genericfill_leadingedge_gloss.dds"},
--Player attributes bars
{"unitattributevisualizer","attributebar_dynamic_fill_gloss.dds"},
{"unitattributevisualizer","attributebar_dynamic_leadingedge_gloss.dds"},
{"unitattributevisualizer","attributebar_small_fill_center_gloss.dds"},
{"unitattributevisualizer","attributebar_small_fill_leadingedge_gloss.dds"},
}
local smooth={
"ZO_CompassFrameCenterTopMungeOverlay",
"ZO_CompassFrameCenterBottomMungeOverlay",
"ZO_PlayerAttributeHealthFrameCenterTopMunge",
"ZO_PlayerAttributeHealthFrameCenterBottomMunge",
"ZO_PlayerAttributeMagickaFrameCenterTopMunge",
"ZO_PlayerAttributeMagickaFrameCenterBottomMunge",
"ZO_PlayerAttributeStaminaFrameCenterTopMunge",
"ZO_PlayerAttributeStaminaFrameCenterBottomMunge",
"ZO_TargetUnitFramereticleoverFrameCenterTopMunge",
"ZO_TargetUnitFramereticleoverFrameCenterBottomMunge",
"ZO_IncreasedArmorFrameContainerArrow1FrameCenterBottomMunge",
"ZO_IncreasedArmorFrameContainerArrow1FrameCenterTopMunge",
"ZO_WorldMapMapFrameBottomMunge",
"ZO_WorldMapMapFrameTopMunge",
"ZO_WorldMapMapFrameLeftMunge",
"ZO_WorldMapMapFrameRightMunge",
}
local color

local function Setup_ActionSlot()
	local normal=BUI.Vars.Theme<=3 and "/esoui/art/actionbar/abilityframe64_up.dds" or "/MyUI/textures/theme/abilityframe64_up.dds"
	BUI.abilityframe=normal
--	local mouseDown=BUI.Vars.Theme<=3 and "/esoui/art/actionbar/abilityframe64_down.dds" or "/MyUI/textures/theme/abilityframe64_down.dds"

	--Action slots
	for i=3,9 do
		local name=i==9 and "QuickslotButton" or "ActionButton"..i
		local frame=_G[name]
		if frame then
			local button=frame:GetNamedChild("Button")
			button:SetNormalTexture("") button:SetPressedTexture("")
			local size=frame:GetWidth()
--			ZO_ActionBar1:GetScale()
			local edge=_G[name.."Edge"] or WINDOW_MANAGER:CreateControl("$(parent)Edge", frame, CT_TEXTURE)
			edge:SetDimensions(size,size)
			edge:ClearAnchors()
			edge:SetAnchor(TOPLEFT,frame,TOPLEFT,0,0)
			edge:SetTexture(normal)
			if color then edge:SetColor(unpack(color)) end edge:SetDrawLayer(2)
			local backdrop=frame:GetNamedChild("Backdrop") if backdrop then backdrop:SetAlpha(0) end
			local bg=frame:GetNamedChild("BG") if bg then bg:SetHidden(false) end
			if i==8 then backdrop=frame:GetNamedChild("Frame") if backdrop then backdrop:SetAlpha(0) end end
		end
	end
end

local function Setup_TargetFrame()
	local texture=BUI.Vars.Theme<=3 and "/esoui/art/unitattributevisualizer/targetbar_dynamic_frame.dds" or "/MyUI/textures/theme/targetbar_dynamic_frame.dds"
	for _,text in pairs({"Center","Left","Right"}) do
		local frame=_G["ZO_TargetUnitFramereticleoverFrame"..text]
		if frame then frame:SetTexture(texture) if color then frame:SetColor(unpack(color)) end end
	end
end

-- My UI console: do not draw decorative Advanced Theme geometry.
-- Core theme textures, functional bars, and editor selection outlines remain.
local function Setup_AdvancedTheme()
    for _,name in ipairs({"BUI_AdvancedTheme", "BUI_Chat_Edge", "BUI_Compass_Edge"}) do
        local control=rawget(_G,name)
        if control and control.SetHidden then control:SetHidden(true) end
    end
    -- Preserve the PlayStation quest interaction hints in every theme.
    local label=rawget(_G,"ZO_FocusedQuestTrackerPanelContainerQuestContainerAssistedKeyLabel")
    if label and label.SetHidden then label:SetHidden(false) end

end

function BUI.Themes_Setup(change)
	color=BUI.Vars.Theme==6 and {1,204/255,248/255,1} or BUI.Vars.Theme==7 and BUI.Vars.AdvancedThemeColor or BUI.Vars.Theme>3 and BUI.Vars.CustomEdgeColor or {1,1,1,1}
	--Progress bar
	if BUI.Vars.Theme==4 or BUI.Vars.Theme==5 then
--		RedirectTexture("/esoui/art/miscellaneous/progressbar_frame.dds","/MyUI/textures/theme/progressbar_frame.dds")
--		for i,data in pairs(textures) do RedirectTexture("/esoui/art/"..data[1].."/"..data[2],"/MyUI/textures/theme/"..data[2]) end
	end
	--Attribute bar textures
	BUI.Frames.ChangeTextures()
	--Smooth
	local a=(BUI.Vars.Theme==1) and 1 or 0
	for i,name in pairs(smooth) do
		local control=_G[name] if control then control:SetAlpha(a) end
	end
	--Pink pony
	if BUI.Vars.Theme==6 then
		if BUI_Theme_Pony then
			BUI_Theme_Pony:SetHidden(false)
		else
			local scale=GetCVar("UseCustomUIScale.2")=="0" and .8 or tonumber(GetCVar("CustomUIScale"))
			BUI.UI.Statusbar("BUI_Theme_Pony",QuickslotButton,{128*scale,128*scale},{BOTTOMRIGHT,BOTTOMRIGHT,0,0},{1,1,1,1},"/MyUI/textures/pink_pony.dds",false)
		end
	elseif BUI_Theme_Pony then
		BUI_Theme_Pony:SetHidden(true)
	end
	--Player exp bar
	local texture=BUI.Vars.Theme<=3 and "/esoui/art/miscellaneous/progressbar_frame.dds" or "/MyUI/textures/theme/progressbar_frame.dds"
	for _,text in pairs({"Middle","Left","Right"}) do local frame=_G["ZO_PlayerProgressBarOverlay"..text] if frame then frame:SetTexture(texture) if color then frame:SetColor(unpack(color)) end end end
	--Attribute bars
	local texture=BUI.Vars.Theme<=3 and "/esoui/art/unitattributevisualizer/attributebar_dynamic_frame.dds" or "/MyUI/textures/theme/attributebar_dynamic_frame.dds"
	local bars={"ZO_PlayerAttributeHealth","ZO_PlayerAttributeMagicka","ZO_PlayerAttributeStamina"}
	for _,bar in pairs(bars) do
		for _,text in pairs({"Center","Left","Right"}) do
			local frame=_G[bar.."Frame"..text] if frame then frame:SetTexture(texture) if color then frame:SetColor(unpack(color)) end end
--			local frame=_G[bar.."BgContainerBG"..text] if frame then frame:SetTexture(fill) end
		end
	end
	local frame=_G["ZO_PlayerAttributeSiegeHealthFrame"] if frame then
		local texture=BUI.Vars.Theme<=3 and "/esoui/art/unitattributevisualizer/attributebar_small_frame_center.dds" or "/MyUI/textures/theme/attributebar_small_frame_center.dds"
		frame:SetTexture(texture) if color then frame:SetColor(unpack(color)) end
	end
	local frame=_G["ZO_PlayerAttributeWerewolfFrame"] if frame then
        -- Keep the original ESO outline; do not apply the oversized theme frame.
        frame:SetTexture("/esoui/art/unitattributevisualizer/attributebar_small_frame.dds")
        frame:SetColor(1, 1, 1, 1)
        frame:SetHidden(false)
    end
	local frame=_G["ZO_PlayerAttributeMountStaminaFrame"] if frame then
        -- Keep the original ESO outline; do not apply the oversized theme frame.
        frame:SetTexture("/esoui/art/unitattributevisualizer/attributebar_small_frame.dds")
        frame:SetColor(1, 1, 1, 1)
        frame:SetHidden(false)
    end
	--Target frame
	Setup_TargetFrame()
	--Worldmap
	local frame=_G["ZO_WorldMapMapFrame"] if frame then
		local texture=BUI.Vars.Theme<=3 and "/esoui/art/worldmap/worldmap_frame_edge.dds" or "/MyUI/textures/theme/worldmap_frame_edge.dds"
		frame:SetEdgeTexture(texture,128,16,16) if color then frame:SetEdgeColor(unpack(color)) end
	end
	--ActionBar
	if BUI.Vars.ActionSlots then Setup_ActionSlot() end
	-- Xbox adaptation: keep the complete compass / top boss-bar frame native.
	-- ESO reuses the compass frame behind the large boss health bar. Styling only
	-- the brackets was not enough and caused the red fill to appear outside the
	-- themed top/bottom lines. Keep all of these textures and colors at ESO defaults.
	for _,text in pairs({"Center","Left","Right"}) do
		local frame=_G["ZO_CompassFrame"..text]
		if frame then frame:SetTexture("/esoui/art/compass/compass.dds") frame:SetColor(1,1,1,1) end
	end
	local frame=_G["ZO_BossBarBracketLeft"] if frame then frame:SetTexture("/esoui/art/bossbar/bossbar_bracket_left.dds") frame:SetColor(1,1,1,1) end
	local frame=_G["ZO_BossBarBracketRight"] if frame then frame:SetTexture("/esoui/art/bossbar/bossbar_bracket_right.dds") frame:SetColor(1,1,1,1) end
	--Change frame colors
	if change then
		if BUI.init.Frames then BUI.Frames:Initialize() end
		if BUI.init.Actions then BUI.Actions.ChangeTheme() end
		if BUI.Vars.PlayerBuffs or BUI.Vars.TargetBuffs or BUI.Vars.EnableCustomBuffs or BUI.Vars.EnableWidgets then BUI.Buffs:Initialize() end
		BUI.CustomBarUpdate(true)
	end

	Setup_AdvancedTheme()
end


function BUI.Frames.ChangeTextures()
	local v=BUI.Vars.Theme
	-- Keep ESO's native boss-health textures. The generic Bandits status-bar
	-- texture can extend vertically outside the thin ZO_BossBar bracket on the
	-- Xbox client. Other resource bars continue to use the selected BUI texture.
	local bars={ZO_TargetUnitFramereticleoverBarLeft=true,ZO_TargetUnitFramereticleoverBarRight=true,ZO_PlayerAttributeHealthBarRight=false,ZO_PlayerAttributeHealthBarLeft=false,ZO_PlayerAttributeStaminaBar=false,ZO_PlayerAttributeMagickaBar=false,ZO_PlayerAttributeSiegeHealthBarLeft=true,ZO_PlayerAttributeSiegeHealthBarRight=true,ZO_PlayerAttributeWerewolfBar=true,ZO_PlayerAttributeMountStaminaBar=true}
	for bar,half in pairs(bars) do
		local gloss=_G[bar.."Gloss"]
		if gloss then gloss:SetHidden(v==3 or v==5 or v==7) end
		if (v==3 or v==5 or v==7) and not BUI.GamepadMode then
			local frame=_G[bar]
			if frame then
				local h=frame:GetHeight()
				frame:SetTexture(BUI.Textures[BUI.Vars.FramesTexture])
				frame:SetTextureCoords(0,1,(half and .5 or 0),1)
				frame:SetLeadingEdge(BUI.Texture_edge[BUI.Vars.FramesTexture],h*(half and .8235 or .647),h)
				frame:SetLeadingEdgeTextureCoords(0,1,(half and .5 or 0),1)
			end
		end
	end
--	if v==3 or v==5 then for i,data in pairs(flat) do RedirectTexture("/esoui/art/"..data[1].."/"..data[2],"/MyUI/textures/theme/blank.dds") end end
end

function BUI.Frames.ZO_PlayerAttribute_toggle(update)
	local frames={['Health']=POWERTYPE_HEALTH,['Stamina']=POWERTYPE_STAMINA,['Magicka']=POWERTYPE_MAGICKA,['MountStamina']=POWERTYPE_MOUNT_STAMINA,['SiegeHealth']=POWERTYPE_HEALTH,['Werewolf']=POWERTYPE_WEREWOLF}
	--Disables Default Frames
	if not BUI.Vars.DefaultPlayerFrames then
		for name in pairs(frames) do
			local frame=_G["ZO_PlayerAttribute"..name]
			frame:UnregisterForEvent(EVENT_POWER_UPDATE)
			frame:UnregisterForEvent(EVENT_INTERFACE_SETTING_CHANGED)
			frame:UnregisterForEvent(EVENT_PLAYER_ACTIVATED)
			frame:UnregisterForEvent(EVENT_UNIT_CREATED)
			EVENT_MANAGER:UnregisterForUpdate("ZO_PlayerAttribute"..name.."FadeUpdate")
			frame:SetHidden(true)
		end
	--Enables Default Frames
	elseif update then
		for name,powerType in pairs(frames) do
			local frame=_G["ZO_PlayerAttribute"..name]
			local bar=frame.playerAttributeBarObject
			frame:RegisterForEvent(EVENT_POWER_UPDATE, function(_, unitTag, powerPoolIndex, powerType, current, max, effectiveMax) bar:OnPowerUpdate(unitTag, powerPoolIndex, powerType, current, max, effectiveMax) end)
			frame:AddFilterForEvent(EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, powerType)
			frame:RegisterForEvent(EVENT_INTERFACE_SETTING_CHANGED, function(_, settingType, settingId) bar:OnInterfaceSettingChanged(settingType, settingId) end)
			frame:AddFilterForEvent(EVENT_INTERFACE_SETTING_CHANGED, REGISTER_FILTER_SETTING_SYSTEM_TYPE, SETTING_TYPE_UI)
			frame:RegisterForEvent(EVENT_PLAYER_ACTIVATED, function() bar:OnPlayerActivated() end)
			EVENT_MANAGER:RegisterForUpdate(frame:GetName() .. "FadeUpdate", 1500, function() bar:UpdateContextualFading() end)
			frame:SetHidden(false)
		end
	end
end

function BUI.Frames.ZO_PlayerAttribute_reposition()
	if not BUI.Vars.DefaultPlayerFrames then return end
	if BUI.Vars.RepositionFrames then
		local _, point, relativeTo, relativePoint, offsetX, offsetY=ZO_PlayerAttributeHealth:GetAnchor()
		if not BUI.Vars.ZO_PlayerAttributeHealth then
			ZO_PlayerAttributeHealth:ClearAnchors()
			ZO_PlayerAttributeHealth:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY-40)
		end
		if not BUI.Vars.ZO_PlayerAttributeMagicka then
			ZO_PlayerAttributeMagicka:ClearAnchors()
			ZO_PlayerAttributeMagicka:SetAnchor(TOPRIGHT, ZO_PlayerAttributeHealth, BOTTOM, -2.5, 8)
		end
		if not BUI.Vars.ZO_PlayerAttributeStamina then
			ZO_PlayerAttributeStamina:ClearAnchors()
			ZO_PlayerAttributeStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeHealth, BOTTOM, 2.5, 8)
		end
		if not BUI.Vars.ZO_PlayerAttributeSiegeHealth then
			--Shift to the right siege weapon health and ram control
			ZO_PlayerAttributeSiegeHealth:ClearAnchors()
			ZO_PlayerAttributeSiegeHealth:SetAnchor(CENTER, ZO_PlayerAttributeHealth, CENTER, 300, 0)
		end
		if not BUI.Vars.ZO_RamTopLevel then
			ZO_RAM.control:ClearAnchors()
			ZO_RAM.control:SetAnchor(BOTTOM, ZO_PlayerAttributeHealth, TOP, 300, 0)
		end
	else
		ZO_PlayerAttributeHealth:ClearAnchors()
		ZO_PlayerAttributeHealth:SetAnchor(CENTER, ZO_PlayerAttribute, CENTER, 0, 0)
		ZO_PlayerAttributeMagicka:ClearAnchors()
		ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttribute, LEFT, 237, 0)
		ZO_PlayerAttributeStamina:ClearAnchors()
		ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttribute, RIGHT, -237, 0)
		ZO_PlayerAttributeSiegeHealth:ClearAnchors()
		ZO_PlayerAttributeSiegeHealth:SetAnchor(TOP, ZO_PlayerAttributeHealth, BOTTOM, 0, -1)
	end
end

function BUI.Frames.ZO_Frame_reposition()
    if BUI.Vars then
        -- Restore ESO's native alert position; remove old saved overrides.
        BUI.Vars.ZO_AlertTextNotification=nil
        BUI.Vars.ZO_FocusedQuestTrackerPanel=nil
        BUI.Vars.ZO_BattlegroundHUDFragmentTopLevelBattlegroundScoreHud=nil
        BUI.Vars.ZO_EndDunHUDTrackerContainer=nil
    end
    -- Scale only the three native trackers and Player Interaction.
    for _,name in ipairs({'ZO_FocusedQuestTrackerPanel',
        'ZO_BattlegroundHUDFragmentTopLevelBattlegroundScoreHud',
        'ZO_EndDunHUDTrackerContainer','ZO_PlayerToPlayerAreaPromptContainer'}) do
        local c=rawget(_G,name)
        if c and c.SetScale then c:SetScale(0.90) end
    end
    local tracker=rawget(_G,'ZO_HUDTrackers') or rawget(_G,'ZO_FocusedQuestTrackerPanel')
    local position=BUI.Vars and BUI.Vars.MyUI_TrackerCombined
    if tracker and type(position)=='table' and position[3] and position[4] then
        tracker:ClearAnchors()
        tracker:SetAnchor(CENTER,GuiRoot,CENTER,position[3],position[4])
    end
	BUI.ThemeHooks=BUI.ThemeHooks or {methods={}}
	local hookState=BUI.ThemeHooks
	local function SetupFunction(control, data)
		control:SetWidth(GuiRoot:GetRight()-ZO_Compass:GetRight()-40)
		control:SetText(data.text)
		control:SetColor(data.color:UnpackRGBA())
		local align=TEXT_ALIGN_RIGHT	--TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER
		
		control:SetHorizontalAlignment(align)
		ZO_SoundAlert(data.category, data.soundId)
	end
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, ' ')
	local line
	if not BUI.GamepadMode then
		line=ZO_AlertTextNotification:GetChild(1)
--		line.fadingControlBuffer.templates.ZO_AlertLine.setup=SetupFunction
		
	else
		line=ZO_AlertTextNotificationGamepad:GetChild(1)
--		line.fadingControlBuffer.templates.ZO_AlertLineGamepad.setup=SetupFunction
	end

	local function ApplyTemplateHook(obj,name,func)
		local key=name..":"..func
		if hookState.methods[key] then return end
		hookState.methods[key]=true
		local ZO_Func=obj[func]
		obj[func]=function(self)
			local result=ZO_Func(self)
			if BUI.Vars[name] then
				local frame=_G[name] frame:ClearAnchors() frame:SetAnchor(BUI.Vars[name][1],GuiRoot,BUI.Vars[name][2],BUI.Vars[name][3],BUI.Vars[name][4])
			end
			return result
		end
	end

	local protectedTemplateControls={
		ZO_CompassFrame_Keyboard_Template="ZO_CompassFrame",
		ZO_CompassFrame_Gamepad_Template="ZO_CompassFrame",
		ZO_PlayerProgressTemplate="ZO_PlayerProgress",
		ZO_PlayerChampionProgressTemplate="ZO_PlayerProgress",
		ZO_GamepadPlayerProgressTemplate="ZO_PlayerProgress",
		ZO_GamepadPlayerChampionProgressTemplate="ZO_PlayerProgress",
	}
	if not hookState.applyTemplateInstalled then
		hookState.applyTemplateInstalled=true
		local ZO_ApplyTemplateToControl=ApplyTemplateToControl
		ApplyTemplateToControl=function(control, templateName)
			local controlName=protectedTemplateControls[templateName]
			local ownsPosition=controlName and BUI.Vars and BUI.Vars[controlName]
			if ownsPosition and control==rawget(_G,controlName) then return end
			return ZO_ApplyTemplateToControl(control,templateName)
		end
	end
	for name in pairs(BUI.DefaultFrames) do
		local var=BUI.Vars[name]
		if var then
			local frame=_G[name]
			if frame then
				if name=='ZO_ActiveCombatTips' then ApplyTemplateHook(ACTIVE_COMBAT_TIP_SYSTEM,'ZO_ActiveCombatTips','ApplyStyle')
				elseif name=='ZO_CenterScreenAnnounce' then ApplyTemplateHook(CENTER_SCREEN_ANNOUNCE,'ZO_CenterScreenAnnounce','ApplyStyle')
				elseif name=='ZO_CompassFrame' then ApplyTemplateHook(COMPASS_FRAME,'ZO_CompassFrame','ApplyStyle')
				elseif name=='ZO_EndDunHUDTrackerContainer' then ApplyTemplateHook(ZO_HUDTracker_Base, 'ZO_EndDunHUDTrackerContainer','RefreshAnchors') end
				frame:ClearAnchors() frame:SetAnchor(var[1],GuiRoot,var[2],var[3],var[4])
			else
				-- Optional native control not present in the current console scene.
			end
		end
	end
	if BUI.Vars.RepositionFrames then BUI.Frames.ZO_PlayerAttribute_reposition() end

	if not hookState.actionBarOnShowInstalled then
		hookState.actionBarOnShowInstalled=true
		ZO_PreHookHandler(ZO_ActionBar1, 'OnShow', function()
			local scenename=SCENE_MANAGER:GetCurrentSceneName() if scenename=="skills" or scenename=="inventory" then return end
			local name="ZO_ActionBar1"
			if BUI.Vars[name] then
				ZO_ActionBar1:ClearAnchors() ZO_ActionBar1:SetAnchor(BUI.Vars[name][1],GuiRoot,BUI.Vars[name][2],BUI.Vars[name][3],BUI.Vars[name][4])
			end
			if ZO_ActionBar1KeybindBG then ZO_ActionBar1KeybindBG:SetHidden(true) end
		end)
	end
end

function BUI.Themes_Initialize()		
	BUI.abilityframe=BUI.Vars.Theme<=3 and "/esoui/art/actionbar/abilityframe64_up.dds" or "/MyUI/textures/theme/abilityframe64_up.dds"
	--Hide keybinds background
	if ZO_ActionBar1KeybindBG then ZO_ActionBar1KeybindBG:SetHidden(true) end
	--Change default frames
	BUI.Frames.ZO_PlayerAttribute_toggle()
	if BUI.Vars.RepositionFrames then BUI.Frames.ZO_PlayerAttribute_reposition() end

	local function ApplyInitialTheme()
		EVENT_MANAGER:UnregisterForEvent("BUI_Theme_Event", EVENT_PLAYER_ACTIVATED)
		BUI.Frames.ZO_Frame_reposition()
		BUI.Themes_Setup()
	end
	EVENT_MANAGER:UnregisterForEvent("BUI_Theme_Event", EVENT_PLAYER_ACTIVATED)
	if BUI.Initialization and BUI.Initialization.playerActivated then
		BUI.CallLater("BUI_Theme_Activated",25,ApplyInitialTheme)
	else
		EVENT_MANAGER:RegisterForEvent("BUI_Theme_Event", EVENT_PLAYER_ACTIVATED,ApplyInitialTheme)
	end
end

--[[
ZO_BattlegroundHUDFragmentTopLevelBattlegroundScoreHudTeamsSection1
GetPlayerCameraHeading()
Get3DRenderSpaceForward()
Get3DRenderSpaceOrientation()
Get3DRenderSpaceOrigin()

Convert3DLocalPositionToWorldPosition
--]]
