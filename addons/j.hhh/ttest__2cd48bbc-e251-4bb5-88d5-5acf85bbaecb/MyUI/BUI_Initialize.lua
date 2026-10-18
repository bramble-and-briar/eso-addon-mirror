local function OnUIError(eventCode,errorString)
	--Hide some bugs
--	if string.match(errorString,"Too many anchors")~=nil
--	or string.match(errorString,"LibMapPins")~=nil
	if string.match(errorString,"AG_PanelMenuButton")
	or string.match(errorString,"TooltipControlSetOwnerLua")
	then
		--d(errorString)
		ZO_UIErrors_HideCurrent()
	elseif not BUI.Vars.DeveloperMode and string.match(errorString,BUI.name) then
		local ver=tostring((MyUI and MyUI.version) or BUI.Version)
		ZO_UIErrorsTextEdit:SetText(BUI.DisplayName.." v:"..ver.."\n"..errorString)
		ZO_UIErrorsTextEdit:SetCursorPosition(1)
	end
end

-- Keep permanent initialization separate from recurring player/scene refreshes.
-- Every stage is guarded so an accidental second entry cannot add controls,
-- callbacks or hooks again during the same UI session.
BUI.Initialization=BUI.Initialization or {stages={}}
local Initialization=BUI.Initialization
Initialization.stages=Initialization.stages or {}
Initialization.steps=Initialization.steps or {}

local function InitLog(message)
    -- No on-screen diagnostics in production.
end

local function ProtectedStage(stateTable,name,callback)
	if stateTable[name] then return stateTable[name]=="complete" end
	stateTable[name]="running"
	InitLog(name.." gestartet")
	local success,err=pcall(callback)
	if not success then
		stateTable[name]="error: "..tostring(err)
		InitLog(name.." FEHLER: "..tostring(err))
		return false
	end
	stateTable[name]="complete"
	InitLog(name.." erfolgreich")
	return true
end

local function RunInitializationStage(name,callback)
	return ProtectedStage(Initialization.stages,name,callback)
end

local function RunIntegrationStep(name,callback)
	return ProtectedStage(Initialization.steps,name,callback)
end

local function Slash(option)
	local on,off,hold="|c33EE33on|r","|cEE3333off|r","|c33EE33in hold|r"
	if option~="" then
		if option=="t" then
			BUI.Stats.PostTargets()
		elseif option=="dm" then
			if BUI.Vars.DeveloperMode then
				BUI.Vars.DeveloperMode=false
				BUI.Frames.PlayerBuffs_Init()
			else
				BUI.Vars.DeveloperMode=true
--				BUI.Stats:Targets_Init()
--				BUI.Stats:BuffsUp_Init()
			end
			d(BUI.DisplayName..": Developer mode is now "..(BUI.Vars.DeveloperMode and on or off))
		elseif option=="abil" then
			d(BUI.DisplayName..": Ability log "..(BUI.Actions.Log() and on or off))
		elseif option=="hh" then
			BUI.Helper_Toggle()
		elseif option=="state" then
			local inHold=BUI.Vars.PvPmode and BUI.PvPzone
			d(BUI.DisplayName.." version: "..BUI.Version,
			"Group notifications: "..(BUI.Vars.NotificationsGroup and (inHold and hold or on) or off),
			"Combat notifications: "..((BUI.Vars.NotificationsTrial or BUI.Vars.NotificationsWorld) and (inHold and hold or on) or off),
			"DPS share: "..(BUI.Vars.StatsUpdateDPS and (inHold and hold or on) or off),
			"Stats share: "..(BUI.Vars.StatShare and (inHold and hold or on) or off),
			"Combat statistics: "..(BUI.Vars.EnableStats and (inHold and hold or on) or off)
			)
		elseif option=="stats" then
			if BUI.Vars.EnableStats then
				BUI.Vars.EnableStats=false
				BUI.OnScreen.Notification(8,"Reloading UI")
				BUI.CallLater("ReloadUI",1000,ReloadUI)
			else
				BUI.Vars.EnableStats=true
				BUI.Stats.Initialize()
			end
			d("Statistics is now: "..(BUI.Vars.EnableStats and on or off))
		elseif option=="share" then
			BUI.Vars.StatsShareDPS=not BUI.Vars.StatsShareDPS
			d("DPS share is now: "..(BUI.Vars.StatsShareDPS and on or off))
		else
			d(BUI.DisplayName..":",
				"/bui - open add-on menu",
				"/bui state - post add-on state",
				"/bui dm - toggle developer mode",
				"/bui hh - show Healer Helper",
				"/bui abil - toggle ability log",
				"/bui stats - toggle combat statistics",
				"/bui share - toggle dps share",
				"/daily - post daily pledges",
				"/rl - reloadui"
--				"/scan UI_Object [compact] - post UI object info"
				)
		end
	else
		BUI.Menu.Open()
	end
end

--Developers function
local function ScanObj(control_name,compact)
	local control=_G[control_name]
	if not control then d(control_name..": |cff2222no such control!|r") return end
	local c_type={[CT_BACKDROP]="BACKDROP",[CT_BUTTON]="BUTTON",[CT_COLORSELECT]="COLORSELECT",[CT_COMPASS]="COMPASS",[CT_CONTROL]="CONTROL",[CT_COOLDOWN]="COOLDOWN",[CT_DEBUGTEXT]="DEBUGTEXT",[CT_EDITBOX]="EDITBOX",[CT_INVALID_TYPE]="INVALID_TYPE",[CT_LABEL]="LABEL",[CT_LINE]="LINE",[CT_MAPDISPLAY]="MAPDISPLAY",[CT_ROOT_WINDOW]="ROOT_WINDOW",[CT_SCROLL]="SCROLL",[CT_SLIDER]="SLIDER",[CT_STATUSBAR]="STATUSBAR",[CT_TEXTBUFFER]="TEXTBUFFER",[CT_TEXTURE]="TEXTURE",[CT_TEXTURECOMPOSITE]="TEXTURECOMPOSITE",[CT_TOOLTIP]="TOOLTIP",[CT_TOPLEVELCONTROL]="TOPLEVELCONTROL"}
	local function GetObjType(obj)
		local obj_type=obj:GetType()
		local text=c_type[obj_type]
		if obj_type==CT_TEXTURE then text=text.." |t26:26:"..obj:GetTextureFileName().."|t"
		elseif obj_type==CT_LABEL then text=text.." \""..obj:GetText().."\""
		end
		return text
	end

--	zo_callLater(function()
	local total=control:GetNumChildren()
	d("==["..total.."] "..control:GetName()..(control:IsHidden() and " |cff2222hidden" or " |c22ff22visible").."|r "..GetObjType(control)..":")
	for i=1,total do
		local obj=control:GetChild(i)
		if obj then
			local hidden=obj:IsHidden()
			if compact==nil or (compact and not hidden) or (compact==false and hidden) then
				d("|cdddddd["..i.."]|r "..obj:GetName()..(hidden and " |cff2222hidden" or " |c22ff22visible").."|r "..GetObjType(obj))
				if compact==nil or (compact and not hidden) or (compact==false and hidden) then
					for i1=1,obj:GetNumChildren() do
						local obj1=obj:GetChild(i1)
						if obj1 then
						d("---|cdddddd["..i1.."]|r "..obj1:GetName()..(obj1:IsHidden() and " |cff2222hidden" or " |c22ff22visible").."|r "..GetObjType(obj1))
						end
					end
				end
			end
		end
	end
--	end,1000)
end

local function UI_Initialize()
	if Initialization.uiInitialized then
		InitLog("UI initialization skipped - already initialized")
		return
	end
	Initialization.uiInitialized=true
	BUI.UI.TopLevelWindow("SatuveUI", GuiRoot, {GuiRoot:GetWidth(),GuiRoot:GetHeight()}, {CENTER,CENTER,0,0}, true) SatuveUI:SetDrawLayer(0)
	--Reference the SatuveUI layer as a scene fragment
	if not BUI.UI.fragment then
		BUI.UI.fragment=ZO_HUDFadeSceneFragment:New(SatuveUI)
		--Add the fragment to select scenes once
		SCENE_MANAGER:GetScene("hud"):AddFragment(BUI.UI.fragment)
		SCENE_MANAGER:GetScene("hudui"):AddFragment(BUI.UI.fragment)
		SCENE_MANAGER:GetScene("siegeBar"):AddFragment(BUI.UI.fragment)
	end
	--Create 3D Render Space
	ParticleUI=rawget(_G,PARTICLE_PREFIX) or WINDOW_MANAGER:CreateTopLevelWindow(PARTICLE_PREFIX)
	ParticleUI:SetHidden(false)
	ParticleUI:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,0)
	ParticleUI:SetDimensions(1,1)
	ParticleUI:SetClampedToScreen(false)
--	WINDOW_MANAGER:CreateControl("BUI_Camera", ParticleUI, CT_TEXTURE) BUI_Camera:SetHidden(true)
end

local function VersionCheck()
	local changed=false
	if BUI.API>100033 then
--		BUI.Vars.ReticleResist=3
		BUI.Vars.ChampionHelper=nil
		BUI.Vars.PlayerStatSection=nil
	end
	if BUI.Vars.LastVersion*1000<=2177 then
		BUI.Vars.ZoomZone			=BUI.MiniMap.Defaults.ZoomZone
		BUI.Vars.ZoomSubZone		=BUI.MiniMap.Defaults.ZoomSubZone
		BUI.Vars.ZoomDungeon		=BUI.MiniMap.Defaults.ZoomDungeon
		BUI.Vars.ZoomImperialsewer	=BUI.MiniMap.Defaults.ZoomImperialsewer
		BUI.Vars.ZoomImperialCity	=BUI.MiniMap.Defaults.ZoomImperialCity
		BUI.Vars.ZoomGlobal		=BUI.MiniMap.Defaults.ZoomGlobal
		changed=true
		bui_pl("My UI: New version. Minimap zoom settings are resetted to defaults")
	end
	if BUI.Vars.LastVersion*1000<3189 then
		BUI.Vars.FrameHeight=BUI.Defaults.FrameHeight
		BUI.Vars.BUI_PlayerFrame=BUI.Defaults.BUI_PlayerFrame
		BUI.Vars.BUI_HPlayerFrame=BUI.Defaults.BUI_HPlayerFrame
		changed=true
		bui_pl("My UI: New version. Some players frames settings are resetted to defaults")
	end
	if BUI.Vars.LastVersion*1000<3193 then
		BUI.Vars.BUI_OnScreen=BUI.Defaults.BUI_OnScreen
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3201 then
		BUI.Vars.ReticleReflection=nil BUI.Vars.ReticleOffBalance=nil
		BUI.Vars.ReticleCcImmunity=nil BUI.Vars.ReticleObImmunity=nil
		BUI.Vars.ReticleIconSize=nil
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3202 then
		if BUI.Vars.FrameOpacityOut==0 then BUI.Vars.FrameOpacityOut=BUI.Defaults.FrameOpacityOut end
		if BUI.Vars.CurvedFrame~="Disabled" then bui_pl("My UI: Curved frames are changed. Settings are resetted to defaults") end
		for n,v in pairs(BUI.Curved.Defaults) do BUI.Vars[n]=v end
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3222 then
		BUI.Vars.StatShareUlt=BUI.Vars.StatShareOnlyHorn and 2 or BUI.Vars.StatShareUlt and 1 or 3
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3226 then
		for id in pairs(BUI.Vars.Widgets) do
			local data=BUI.Vars["BUI_Widget_"..string.gsub(id," ","_")]
			if data then data[8]=BUI.Vars.WidgetsProgress end
		end
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3238 then
		for _,data in pairs(BUI.Vars.Reports) do
			table.insert(BUI.Reports.data,data)
		end
		BUI.Vars.Reports=nil
		changed=true
	end
	if BUI.Vars.LastVersion*1000<3244 then
		BUI.Vars.ZO_LootHistoryControl_Gamepad=nil
		changed=true
	end
	if type(BUI.Vars.TauntTimer)~="number" then BUI.Vars.TauntTimer=BUI.Defaults.TauntTimer changed=true end
	if type(BUI.Vars.RoundedBars)~="number" then BUI.Vars.RoundedBars=BUI.Defaults.RoundedBars changed=true end
	if BUI.Vars.LastVersion*1000<4000 then
		local formats={["name"]=1,["account"]=2,["name+account"]=4}
		BUI.Vars.FrameNameFormat=formats[BUI.Vars.FrameNameFormat]
		changed=true
	end
	if type(BUI.Vars.GroupDeathSound)~="string" then BUI.Vars.GroupDeathSound="Lockpicking_unlocked" end
	if BUI.Vars.CurvedFrame==4 or type(BUI.Vars.CurvedFrame)~="number" then BUI.Vars.CurvedFrame=1 pl("My UI: Curved frames are changed. Settings are resetted to defaults") end
	if changed then BUI.Vars.LastVersion=BUI.Version end
	-- Satuve Xbox UI readability migration for large/high-resolution displays.
	-- Preserve larger user settings, but raise values that are too small to read.
	BUI.Vars.FrameFontSize = math.max(tonumber(BUI.Vars.FrameFontSize) or 0, 20)
	BUI.Vars.RaidFontSize = math.max(tonumber(BUI.Vars.RaidFontSize) or 0, 21)
	BUI.Vars.FrameHeight = math.max(tonumber(BUI.Vars.FrameHeight) or 0, 28)
	BUI.Vars.TargetHeight = math.max(tonumber(BUI.Vars.TargetHeight) or 0, 30)
	BUI.Vars.NotificationsSize = math.max(tonumber(BUI.Vars.NotificationsSize) or 0, 36)

	local accessibilityModeEnabled = GetSetting_Bool(SETTING_TYPE_ACCESSIBILITY, ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
	if BUI.Vars.DisableHelpAnnounce==false then
		if accessibilityModeEnabled then bui_pl("My UI: " .. BUI.Loc("AccessibilityHelpAnnouncement")) end
	end
end

local function Initialize(eventCode, addOnName)
	if addOnName~=BUI.name then
		if addOnName=="MyUI" then InitLog("NAMENSFEHLER: erwartet "..tostring(BUI.name)..", erhalten MyUI") end
		return
	end
	EVENT_MANAGER:UnregisterForEvent("BUI_Event", EVENT_ADD_ON_LOADED)
	if Initialization.addOnLoadedHandled then
		InitLog("ADD_ON_LOADED skipped - already handled")
		return
	end
	Initialization.addOnLoadedHandled=true
	InitLog("ADD_ON_LOADED")

	-- Track the first activation without doing permanent work in that event.
	local lifecycleEvent="MyUI_InitLifecycle"
	EVENT_MANAGER:UnregisterForEvent(lifecycleEvent,EVENT_PLAYER_ACTIVATED)
	EVENT_MANAGER:RegisterForEvent(lifecycleEvent,EVENT_PLAYER_ACTIVATED,function()
		Initialization.playerActivated=true
		InitLog("PLAYER_ACTIVATED")
		EVENT_MANAGER:UnregisterForEvent(lifecycleEvent,EVENT_PLAYER_ACTIVATED)
	end)
	local isPlayerActivated=rawget(_G,"IsPlayerActivated")
	if type(isPlayerActivated)=="function" and isPlayerActivated() then
		Initialization.playerActivated=true
	end

	RunInitializationStage("saved variables",function()
		BUI.Vars=ZO_SavedVars:NewAccountWide('SATUVE_XBOX_UI_VARS', 3, nil, BUI.Defaults)
		BUI.Reports=ZO_SavedVars:NewAccountWide('SATUVE_XBOX_UI_REPORTS', 1, nil, {data={}})
		VersionCheck()
	end)

	RunInitializationStage("root UI",function()
		ZO_UIErrors:ClearAnchors()
		ZO_UIErrors:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
		EVENT_MANAGER:UnregisterForEvent("BUI_ErrorManager", EVENT_LUA_ERROR)
		EVENT_MANAGER:RegisterForEvent("BUI_ErrorManager", EVENT_LUA_ERROR, OnUIError)
		UI_Initialize()
	end)

	-- Split the former single-frame startup burst into bounded one-shot stages.
	BUI.CallLater("BXUI_InitPlayer",25,function()
		RunInitializationStage("player UI",function()
			BUI.Player:Initialize()
			BUI.Reticle.Initialize()
			BUI.Target:Initialize()
		end)
	end)

	BUI.CallLater("BXUI_InitCombat",75,function()
		RunInitializationStage("combat UI",function()
			BUI.Damage.Initialize()
			BUI.Stats.Initialize()
			BUI.Buffs.Initialize()
		end)
	end)

	BUI.CallLater("BXUI_InitActionBars",150,function()
		RunInitializationStage("action bars and frames",function()
			BUI.Themes_Initialize()
			BUI.Actions.Initialize()
			BUI.Frames:Initialize()
			BUI.StatShare.Initialize()
			BUI.RG:Initialize()
			BUI.OnScreen.Initialize()
			BUI.Meters.Initialize()
			if BUI.ChampionPriority and BUI.ChampionPriority.Initialize then BUI.ChampionPriority:Initialize() end
		end)
	end)

	BUI.CallLater("BXUI_InitIntegrations",250,function()
		RunInitializationStage("menus and integrations",function()
			RunIntegrationStep("Menu.Init",function() BUI.Menu.Init() end)
			RunIntegrationStep("Menu.Initialize",function() BUI.Menu.Initialize() end)
			RunIntegrationStep("MiniMap",function() BUI.MiniMap.Initialize() end)
			RunIntegrationStep("Automation",function() BUI.Automation_Init() end)
			RunIntegrationStep("Panel",function() BUI.Panel_Init() end)
			RunIntegrationStep("CustomBar",function() BUI.CustomBar_Init() end)
			RunIntegrationStep("LAM.FinalizeGrouped",function()
				if not BUI.SettingsBridge or not BUI.SettingsBridge.FinalizeGrouped then error("LAM-Bridge nicht geladen") end
				local ok=BUI.SettingsBridge.FinalizeGrouped("BUI_BanditUI")
				if not ok then error("LAM-Panel nicht registriert (LAM fehlt oder RegisterAddonPanel gab nil zurueck)") end
			end)
			RunIntegrationStep("RegisterEvents",function() BUI.RegisterEvents(Initialization.playerActivated) end)
			RunIntegrationStep("SlashCommands",function()
				SLASH_COMMANDS["/bui"]=Slash
				SLASH_COMMANDS["/daily"]=BUI.DailyPledges
				SLASH_COMMANDS["/ab"]=function(id) id=tonumber(id) if id and id>0 then StartChatInput('['..id..']=true,--'..GetAbilityName(id)) end end
				SLASH_COMMANDS["/rl"]=function() BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI) end
				SLASH_COMMANDS["/scan"]=function(params) params={string.match(params, "^(%S*)%s*(.-)$")} ScanObj(params[1], params[2]~="") end
			end)
			RunIntegrationStep("BUI_Ready",function()
				if not Initialization.readyFired then
					Initialization.readyFired=true
					CALLBACK_MANAGER:FireCallbacks("BUI_Ready")
				end
			end)
		end)
	end)
end

EVENT_MANAGER:RegisterForEvent("BUI_Event", EVENT_ADD_ON_LOADED, Initialize)
