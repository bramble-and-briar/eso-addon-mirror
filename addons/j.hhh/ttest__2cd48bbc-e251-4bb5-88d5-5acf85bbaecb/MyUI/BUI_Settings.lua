-- MENU OPTIONS COMPONENT
local MenuOptions,MenuPanel,MenuHandlers={},{},{}
local TexturesList={} for t in pairs(BUI.Textures) do table.insert(TexturesList,t) end
local MoveMode_1,MoveMode_2=true,true
local move_init,move_anchor
local MenuIcon={
MenuMisc="/esoui/art/login/authentication_trusted_up.dds",
MenuReticle="/esoui/art/icons/guildranks/guild_indexicon_misc03_up.dds",
MenuPlayerFrames="/esoui/art/mainmenu/menubar_character_up.dds",
--MenuCurvedFrames="/esoui/art/mainmenu/menubar_character_up.dds",
MenuAttackersFrames="/esoui/art/treeicons/collection_indexicon_weapons+armor_up.dds",
MenuTargetFrames="/esoui/art/treeicons/tutorial_idexicon_death_up.dds",
MenuStatShare="/esoui/art/mainmenu/menubar_collections_up.dds",
MenuActions="/esoui/art/treeicons/tutorial_idexicon_timedactivities_up.dds",
MenuNotifications="/esoui/art/help/help_tabicon_tutorial_up.dds",
MenuFrameColors="/esoui/art/tutorial/dyes_tabicon_dye_up.dds",
MenuMeters="esoui/art/treeicons/housing_indexicon_structures_up.dds",
MenuMarkers="/esoui/art/guild/guild_indexicon_leader_up.dds",
}
local MenuNumber={
MenuMisc		="1.  ",
MenuPlayerFrames	="3.  ",
MenuAttackersFrames="4.  ",
--MenuCurvedFrames	="4.  ",
--MenuStatShare	="5.  ",
MenuTargetFrames	="6.  ",
MenuActions		="7.  ",
MenuReticle		="10. ",
MenuNotifications	="12. ",
MenuFrameColors	="13. ",
MenuMeters		="21. ",
MenuMarkers		="22. ",
}
local GroupDeathSounds={
"No_Sound",
"Outfitting_WeaponAdd_Mace",
"Outfitting_ArmorAdd_Light",
"Telvar_Gained",
"Undaunted_Transact",
"Lockpicking_unlocked",
}
local NotificationSounds={
"No_Sound",
"Justice_StateChanged",
"GiftInventoryView_FanfareSparks",
"New_Notification",
"BG_CTF_FlagReturned",
"LevelUpReward_Claim",
"InventoryItem_ApplyEnchant",
"Console_Game_Enter",
"Raid_Trial_Failed",
"Champion_PointsCommitted",
"BG_CTF_FlagCaptured",
"Quest_Complete",
}
local ProcSounds={
"No_Sound",
"Collectible_On_Cooldown",
"Telvar_MultiplierMax",
"Justice_PickpocketBonus",
"BG_MB_BallTaken_OtherTeam",
"Telvar_MultiplierUp",
"Ability_MorphPurchased",
"Objective_Complete",
"Telvar_Gained",
"CrownCrates_Card_Flipping",
"GiftInventoryView_FanfareSparks",
"CrownCrates_Manifest_Selected",
"CrownCrates_Manifest_Chosen",
"Ability_UpgradePurchased",
"Ability_Ultimate_Ready_Sound",
}
local function MenuMiscAdditional()
	--Add additional elements
	local mode1	=BUI.UI.Button(	"BUI_Menu_Move1_Sw",	BUI_MenuMisc,	{26,26},	{BOTTOM,TOP,-10,0,BUI_MenuButton_Move},	BSTATE_NORMAL, nil, nil, nil, nil, nil, false)
	mode1:SetNormalTexture(MoveMode_1 and "/esoui/art/cadwell/checkboxicon_checked.dds" or "esoui/art/cadwell/checkboxicon_unchecked.dds")
	mode1:SetHandler("OnClicked", function(self) MoveMode_1=not MoveMode_1 self:SetNormalTexture(MoveMode_1 and "/esoui/art/cadwell/checkboxicon_checked.dds" or "esoui/art/cadwell/checkboxicon_unchecked.dds") end)
	BUI.UI.Label(	"BUI_Menu_Move1_Label",	mode1,		{60,26},		{RIGHT,LEFT,-4,0},		BUI.UI.Font("standard",18,true), {.8,.8,.6,1}, {2,1}, "Satuve",	false)
	local mode2	=BUI.UI.Button(	"BUI_Menu_Move2_Sw",	BUI_MenuMisc,	{26,26},	{BOTTOM,TOP,90,0,BUI_MenuButton_Move},	BSTATE_NORMAL, nil, nil, nil, nil, nil, false)
	mode2:SetNormalTexture(MoveMode_2 and "/esoui/art/cadwell/checkboxicon_checked.dds" or "esoui/art/cadwell/checkboxicon_unchecked.dds")
	mode2:SetHandler("OnClicked", function(self) MoveMode_2=not MoveMode_2 self:SetNormalTexture(MoveMode_2 and "/esoui/art/cadwell/checkboxicon_checked.dds" or "esoui/art/cadwell/checkboxicon_unchecked.dds") end)
	BUI.UI.Label(	"BUI_Menu_Move2_Label",	mode2,		{60,26},		{RIGHT,LEFT,-4,0},		BUI.UI.Font("standard",18,true), {.8,.8,.6,1}, {2,1}, "Default",	false)
end

ZO_Dialogs_RegisterCustomDialog("BUI_RESET_CONFIRMATION", {
	gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC, allowShowOnNextScene=true},
	title={text=SI_CUSTOMER_SERVICE_SUBMIT_CONFIRMATION},
	mainText=function(dialog) return {text=dialog.data.text} end,
	buttons=
		{
			{text=SI_OK,callback=function(dialog)dialog.data.func()end,keybind="DIALOG_PRIMARY",clickSound=SOUNDS.DIALOG_ACCEPT},
			{text=SI_DIALOG_CANCEL,keybind="DIALOG_NEGATIVE",clickSound=SOUNDS.DIALOG_ACCEPT}
		}
	}
)

local function MenuOptions_Init()	--Menu options
	BUI.Menu.Black_List,BUI.Menu.Black_List_Values=BUI.Menu.MakeList(BUI.Vars.BuffsBlackList)
	BUI.Menu.Custom_List,BUI.Menu.Custom_List_Values=BUI.Menu.MakeList(BUI.Vars.CustomBuffs)
--	local Widgets_List,Widgets_List_Values=BUI.Menu.MakeList(BUI.Vars.Widgets)

	MenuOptions["MenuMisc"]={
	--Reposition Elements
	{	type		="button",
		name		="Move Frames",
		tooltip		="PlayStation: L1/R1 wechseln, Steuerkreuz bewegt, Kreis speichert und schliesst.",
		func		=function()
            if BUI.StartMoveFramesFromChat then BUI.StartMoveFramesFromChat() end
        end,
		reference	="BUI_MenuButton_Move",
	},
	--Reset Default Frames
	{	type		="button",
		name		="ResetPositions",
		func		=function()ZO_Dialogs_ShowDialog ("BUI_RESET_CONFIRMATION", {text=BUI.Loc("ResetPositionsDesc"),func=function()BUI.Menu.Reset("Positions")end})end,
		reference	="BUI_MenuButton_Reset",
	},
	-- Satuve character-specific Champion Point step list
	{	type="header", name="Champion Point Step List"},
	{	type="description", text="One numbered list per character. BLUE, RED and GREEN Champion stars are detected automatically."},
	{	type="button", name="Edit CP Step List", func=function() if BUI.ChampionPriority then BUI.ChampionPriority:Edit() end end},
	{	type="button", name="Preview CP Step List", func=function() if BUI.ChampionPriority then BUI.ChampionPriority:Preview() end end},
	{	type="button", name="Apply CP Step List", func=function() if BUI.ChampionPriority then BUI.ChampionPriority:Apply() end end},
	{	type="button", name="Clear CP Step List", func=function() if BUI.ChampionPriority then BUI.ChampionPriority:ClearList() end end},
	--Theme
	{	type		="header", name="Theme"},
	{	type		="dropdown",
		name		="Theme",
		choices	={"Standard","Standard smooth","Standard flat","Custom gloss","Custom flat","Pink pony","Advanced"},
--		choicesValues={1,2,3,4,5,6,7},
		getFunc	=function() return BUI.Vars.Theme end,
		setFunc	=function(i,value)
			if i==BUI.Vars.Theme then
				--Do nothing
			else
				BUI.Vars.Theme=i BUI.Themes_Setup(true) SCENE_MANAGER:SetInUIMode(false) bui_a("Changing theme: Done")
			end
		end,
	},
	--Frames Texture
	{	type		="dropdown",
		name		="FramesTexture",
		choices	=TexturesList,
		getFunc	=function() return BUI.Vars.FramesTexture end,
		setFunc	=function(i,value) BUI.Menu.UpdateFrames("FramesTexture", value) end,
	},
	--Frames ShortenThreshold
	{	type		="dropdown",
		name		="ShortenThreshold",
		choices	={"1000","10000","100000"},
		getFunc	=function() return tostring(BUI.Vars.ShortenThreshold) end,
		setFunc	=function(i,value) BUI.Vars.ShortenThreshold=tonumber(value) end,
	},	
	--Custom theme Color
	{	type		="colorpicker",
		name		="CustomEdgeColor",
		getFunc	=function() return BUI.Vars.CustomEdgeColor[1],BUI.Vars.CustomEdgeColor[2],BUI.Vars.CustomEdgeColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Vars.CustomEdgeColor={math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1} BUI.Themes_Setup(true) end,
	},
	--Advanced theme Color
	{	type		="colorpicker",
		name		="AdvancedThemeColor",
		getFunc	=function() return BUI.Vars.AdvancedThemeColor[1],BUI.Vars.AdvancedThemeColor[2],BUI.Vars.AdvancedThemeColor[3],BUI.Vars.AdvancedThemeColor[4] end,
		setFunc	=function(r,g,b,a) BUI.Vars.AdvancedThemeColor={math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100, math.floor(a*100)/100} if BUI.Vars.Theme==7 then BUI.Themes_Setup(true) end end,
	},
	--ActionSlots
	{	type		="header",
		name		="ActionSlotsHeader",
	},
	{	type		="checkbox",
		name		="ActionSlots",
		getFunc	=function() return BUI.Vars.ActionSlots end,
		setFunc	=function(value) BUI.Vars.ActionSlots=value BUI.Themes_Setup() end,
	},
	--Misc
	{	type		="header",
		name		="MiscHeader1",
	},
	--Change language
	{	type		="dropdown",
		name		="ChangeLanguage",
		choices	={"en", "ru", "de", "fr", "jp", "it", "br", "pl", "es"},
		getFunc	=function() return BUI.language end,
		setFunc	=function(i,value) SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("Language",1000,SetCVar,"Language.2",value) end,
		warning	="ChangeLanguageWarn",
	},
--[[	--Player attributes section
	{	type		="checkbox",
		name		="PlayerStatSection",
		getFunc	=function() return BUI.Vars.PlayerStatSection end,
		setFunc	=function(value) BUI.Vars.PlayerStatSection=value end,
		warning	=true,
		disabled	=function() return BUI.API>100033 end,
	},
--]]
	--PvPmode
	{	type		="checkbox",
		name		="PvPmode",
		getFunc	=function() return BUI.Vars.PvPmode end,
		setFunc	=function(value) BUI.Vars.PvPmode=value end,
	},
	--PvPmodeAnnouncement
	{	type		="checkbox",
		name		="PvPmodeAnnouncement",
		getFunc	=function() return BUI.Vars.PvPmodeAnnouncement end,
		setFunc	=function(value) BUI.Vars.PvPmodeAnnouncement=value end,
	},
	--DisableHelpAnnounce
	{	type		="checkbox",
		name		="DisableHelpAnnounce",
		getFunc	=function() return BUI.Vars.DisableHelpAnnounce end,
		setFunc	=function(value) BUI.Vars.DisableHelpAnnounce=value end,
	},
--[[	--Champion system helper
	{	type		="checkbox",
		name		="ChampionHelper",
		getFunc	=function() return BUI.Vars.ChampionHelper end,
		setFunc	=function(value) BUI.Vars.ChampionHelper=value BUI.Champion_Init() end,
		disabled	=function() return BUI.API>100033 end,
	},
--]]
	--Reset Addon
	{	type		="button",
		name		="Reset",
		func		=function()ZO_Dialogs_ShowDialog ("BUI_RESET_CONFIRMATION", {text=BUI.Loc("ResetDesc"),func=BUI.Menu.Reset})end,
	}}
	MenuPanel["MenuMisc"]={name="MiscHeader"}
	MenuHandlers["MenuMisc"]={
	OnEffectivelyShown=function()BUI.CallLater("MenuMisc",100,MenuMiscAdditional)end,
	OnEffectivelyHidden=function() BUI.inMenu=false end,
	}

	MenuOptions["MenuReticle"]={
	{	type		="checkbox",
		name		="LeaderArrow",
		getFunc	=function() return BUI.Vars.LeaderArrow end,
		setFunc	=function(value) BUI.Vars.LeaderArrow=value BUI.Reticle.LeaderArrow() end,
	},
	{	type		="checkbox",
		name		="InCombatReticle",
		getFunc	=function() return BUI.Vars.InCombatReticle end,
		setFunc	=function(value) BUI.Vars.InCombatReticle=value end,
	},
	{	type		="checkbox",
		name		="PreferredTarget",
		getFunc	=function() return BUI.Vars.PreferredTarget end,
		setFunc	=function(value) BUI.Vars.PreferredTarget=value end,
	},
	{	type		="checkbox",
		name		="ReticleDpS",
		getFunc	=function() return BUI.Vars.ReticleDpS end,
		setFunc	=function(value) BUI.Vars.ReticleDpS=value end,
		disabled	=function() return not BUI.Vars.StatsMiniMeter end,
	},
	{	type		="checkbox",
		name		="ReticleInvul",
		getFunc	=function() return BUI.Vars.ReticleInvul end,
		setFunc	=function(value) BUI.Vars.ReticleInvul=value if value then BUI.Target:Initialize() end end,
	},
	--Crusher timer
	{	type		="checkbox",
		name		="CrusherTimer",
		getFunc	=function() return BUI.Vars.CrusherTimer end,
		setFunc	=function(value) BUI.Vars.CrusherTimer=value end,
	},
	--Taunt timer
	{	type		="dropdown",
		name		="TauntTimer",
		choices	={"Progress bar","Bar and number","Number only","Disabled"},
		getFunc	=function() return BUI.Vars.TauntTimer end,
		setFunc	=function(i,value) BUI.Vars.TauntTimer=i end,
	},
	{	type		="checkbox",
		name		="TauntTimerSource",
		getFunc	=function() return BUI.Vars.TauntTimerSource end,
		setFunc	=function(value) BUI.Vars.TauntTimerSource=value end,
		disabled	=function() return BUI.Vars.TauntTimer==4 end,
	},
	--Reticle resist
	{	type		="dropdown",
		name		="ReticleResist",
		choices	={"Current value","Detailed info","Disabled"},
--		choicesValues={1,2,3},
		getFunc	=function() return BUI.Vars.ReticleResist end,
		setFunc	=function(i,value) BUI.Vars.ReticleResist=i end,
--		disabled	=function() return BUI.API>100033 end,
	},
	--Cast bar
	{	type		="dropdown",
		name		="CastBar",
		choices	={"Any ability","Cast time ability","Disabled"},
		getFunc	=function() return BUI.Vars.CastBar end,
		setFunc	=function(i,value) BUI.Vars.CastBar=i end,
		disabled	=function() return not BUI.Vars.Actions end,
	},
	--Swap indicator
	{	type		="checkbox",
		name		="SwapIndicator",
		getFunc	=function() return BUI.Vars.SwapIndicator end,
		setFunc	=function(value) BUI.Vars.SwapIndicator=value end,
		disabled	=function() return not BUI.Vars.Actions end,
	},
	--Impactful hit animation
	{	type		="checkbox",
		name		="ImpactAnimation",
		getFunc	=function() return BUI.Vars.ImpactAnimation end,
		setFunc	=function(value) BUI.Vars.ImpactAnimation=value BUI.Reticle.Initialize() end,
	},
	--Reticle mode
	{	type		="dropdown",
		name		="ReticleMode",
		choices	={"Default","Crosshair","Rhomboid","Circular","Triangle 1","Triangle 2","Dotty","Brackets","Dots",[11]="Off"},
		getFunc	=function() return BUI.Vars.ReticleMode end,
		setFunc	=function(i,value) BUI.Vars.ReticleMode=i BUI.Reticle.Mode(i) end,
	},
	--Speed boost
	{	type		="checkbox",
		name		="ReticleBoost",
		getFunc	=function() return BUI.Vars.ReticleBoost end,
		setFunc	=function(value) BUI.Vars.ReticleBoost=value end,
		disabled	=function() return not BUI.Vars.PlayerBuffs end
	},
	--Block indicator
	{	type		="checkbox",
		name		="BlockIndicator",
		getFunc	=function() return BUI.Vars.BlockIndicator end,
		setFunc	=function(value) BUI.Vars.BlockIndicator=value BUI.Reticle.Blocking() end
	},
	{	type="texture",
		texture="/MyUI/textures/reticle/menu_reticle.dds",
		dimensions={128,128}
	}}
	MenuPanel["MenuReticle"]={name="ReticleHeader"}
	MenuHandlers["MenuReticle"]={
	["OnEffectivelyHidden"]=function() BUI.inMenu=false end,
	}

	MenuOptions["MenuPlayerFrames"]={
    { type="slider", name="Basegame Attribute Bar Width", min=250, max=370, step=5,
      getFunc=function() return (BUI.Vars and BUI.Vars.MyUI_NativeAttributeWidth) or 300 end,
      setFunc=function(value)
          BUI.Vars.MyUI_NativeAttributeWidth=value
          if BUI.AttributeWidth then BUI.AttributeWidth.Apply() end
      end,
      default=300,
    },
--		type="submenu", name="PlayerHeader", controls={
	--Player Frames
	{	type		="dropdown",
		name		="PlayerHeader",
		choices	={"Default frames","Default: pyramid","Satuve: default","Satuve: pyramid","Satuve: vertical","Alternative Attribute Bars","Disabled"},
		getFunc	=function()
					if BUI.Vars.MyUI_AlternativeActive then return "Alternative Attribute Bars" end
					if BUI.Vars.DefaultPlayerFrames then
						if BUI.Vars.RepositionFrames then return "Default: pyramid" else return "Default frames" end
					elseif BUI.Vars.PlayerFrame then
						if BUI.Vars.FrameHorisontal then
							return BUI.Vars.RepositionFrames and "Satuve: pyramid" or "Satuve: default"
						else return "Satuve: vertical" end
					else
						return "Disabled"
					end
				end,
		setFunc	=function(i,value)
					local alt=(value=="Alternative Attribute Bars")
                    BUI.Vars.MyUI_AlternativeActive=alt
                    if BUI.AlternativeAttributes and BUI.AlternativeAttributes.SetActive then
                        BUI.AlternativeAttributes.SetActive(false)
                    end
                    if alt then
                        -- Preserve native event handling for werewolf/mount/siege,
                        -- hide only ESO's 3 player resources in the alternative module.
                        local oldDefault=BUI.Vars.DefaultPlayerFrames
                        BUI.Vars.DefaultPlayerFrames=true
                        BUI.Vars.PlayerFrame=false
                        BUI.Vars.RepositionFrames=false
                        if not oldDefault then BUI.Frames:ZO_PlayerAttribute_toggle(true) end
                        BUI.Frames:Controls()
                        if BUI.AlternativeAttributes and BUI.AlternativeAttributes.SetActive then
                            BUI.AlternativeAttributes.SetActive(true)
                        end
                    elseif value=="Default frames" then
						local old1=BUI.Vars.DefaultPlayerFrames BUI.Vars.DefaultPlayerFrames=true
						local old2=BUI.Vars.RepositionFrames BUI.Vars.RepositionFrames=false
						BUI.Vars.PlayerFrame=false
						BUI.Menu.Reset("DefaultFrames")
						if not old1 then BUI.Frames:ZO_PlayerAttribute_toggle(true) end
                        for _, name in ipairs({"Health","Magicka","Stamina"}) do
                            local bar=_G["ZO_PlayerAttribute" .. name]
                            if bar then bar:SetHidden(false) end
                        end
						if old2 then BUI.Frames.ZO_PlayerAttribute_reposition() end
						if BUI_PlayerFrame then BUI_PlayerFrame:SetHidden(true) end
--						if not old1 or old2 then SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI) end
					elseif value=="Default: pyramid" then
						local old1=BUI.Vars.DefaultPlayerFrames BUI.Vars.DefaultPlayerFrames=true
						BUI.Vars.RepositionFrames=true
						BUI.Vars.PlayerFrame=false
						BUI.Frames:ZO_PlayerAttribute_reposition()
						if not old1 then BUI.Frames:ZO_PlayerAttribute_toggle(true) end
                        for _, name in ipairs({"Health","Magicka","Stamina"}) do
                            local bar=_G["ZO_PlayerAttribute" .. name]
                            if bar then bar:SetHidden(false) end
                        end
						if BUI_PlayerFrame then BUI_PlayerFrame:SetHidden(true) end
--						if not old1 then SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI) end
					elseif value=="Satuve: default" then
						BUI.Vars.DefaultPlayerFrames=false
						BUI.Frames:ZO_PlayerAttribute_toggle()
						BUI.Vars.PlayerFrame=true
						BUI.Vars.FrameHorisontal=true
						BUI.Vars.RepositionFrames=false
						BUI.Frames:Controls()
						BUI.Frames:SetupPlayer()
						BUI.Menu:FramesReposition()
					elseif value=="Satuve: pyramid" then
						BUI.Vars.DefaultPlayerFrames=false
						BUI.Frames:ZO_PlayerAttribute_toggle()
						BUI.Vars.PlayerFrame=true
						BUI.Vars.FrameHorisontal=true
						BUI.Vars.RepositionFrames=true
						BUI.Vars.TargetHeight=BUI.Vars.FrameHeight
						BUI.Frames:Controls()
						BUI.Frames:SetupPlayer()
						BUI.Menu:FramesReposition()
					elseif value=="Satuve: vertical" then
						BUI.Vars.DefaultPlayerFrames=false
						BUI.Frames:ZO_PlayerAttribute_toggle()
						BUI.Vars.PlayerFrame=true
						BUI.Vars.FrameHorisontal=false
						BUI.Vars.RepositionFrames=false
						BUI.Vars.TargetHeight=BUI.Vars.FrameHeight*1.5
						BUI.Vars.TargetWidth=BUI.Vars.FrameWidth
						BUI.Frames:Controls()
						BUI.Frames:SetupPlayer()
						BUI.Menu:FramesReposition()
					elseif value=="Disabled" then
						BUI.Vars.DefaultPlayerFrames=false
						BUI.Vars.PlayerFrame=false
						BUI.Vars.FrameHorisontal=true
						BUI.Vars.TargetHeight=BUI.Vars.FrameHeight
						BUI.Frames:ZO_PlayerAttribute_toggle()
						BUI.Frames:Controls()
					end
				end,
		default	="Satuve Player frame",
--		warning	=true,
	},
    -- Alternative Attribute Bars are separate from native and Bandits frames.
    { type="slider", name="Alternative Bar Width", min=240, max=600, step=10,
      getFunc=function() local a=BUI.Vars.MyUI_AlternativeAttributes or {}; return a.width or 360 end,
      setFunc=function(v) BUI.Vars.MyUI_AlternativeAttributes=BUI.Vars.MyUI_AlternativeAttributes or {}; BUI.Vars.MyUI_AlternativeAttributes.width=v; if BUI.AlternativeAttributes and BUI.AlternativeAttributes.Refresh then BUI.AlternativeAttributes.Refresh() end end,
      default=360, disabled=function() return not BUI.Vars.MyUI_AlternativeActive end },
    { type="slider", name="Alternative Bar Height (Gamepad)", min=48, max=140, step=2,
      getFunc=function() local a=BUI.Vars.MyUI_AlternativeAttributes or {}; return a.gamepadHeight or 96 end,
      setFunc=function(v) BUI.Vars.MyUI_AlternativeAttributes=BUI.Vars.MyUI_AlternativeAttributes or {}; BUI.Vars.MyUI_AlternativeAttributes.gamepadHeight=v; if BUI.AlternativeAttributes and BUI.AlternativeAttributes.Refresh then BUI.AlternativeAttributes.Refresh() end end,
      default=96, disabled=function() return not BUI.Vars.MyUI_AlternativeActive end },
    { type="slider", name="Alternative Magicka / Stamina Gap", min=0, max=40, step=1,
      getFunc=function() local a=BUI.Vars.MyUI_AlternativeAttributes or {}; return a.barGap or 5 end,
      setFunc=function(v) BUI.Vars.MyUI_AlternativeAttributes=BUI.Vars.MyUI_AlternativeAttributes or {}; BUI.Vars.MyUI_AlternativeAttributes.barGap=v; if BUI.AlternativeAttributes and BUI.AlternativeAttributes.Refresh then BUI.AlternativeAttributes.Refresh() end end,
      default=5, disabled=function() return not BUI.Vars.MyUI_AlternativeActive end },
    { type="description", text="Move each alternative bar separately under Move Frames (L1/R1, D-pad, Circle). Positions persist after reload." },
	--Frames Border
	{	type		="dropdown",
		name		="FramesBorder",
		choices	={"Plain","Thin","Thin (the same)","Clockwork","Blade","Round","Dragon"},
		getFunc	=function() return BUI.Vars.FramesBorder end,
		setFunc	=function(i,value) BUI.Vars.FramesBorder=i BUI.Frames:Controls() end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Primary Stat
	{	type		="dropdown",
		name		="PrimaryStat",
		choices	={"Default","Stamina","Magicka"},
		getFunc	=function() return BUI.Vars.PrimaryStat end,
		setFunc	=function(i,value) BUI.Vars.PrimaryStat=i BUI.Player:SetPrimaryStat() end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Show Maximum Health
	{	type		="checkbox",
		name		="FrameShowMax",
		getFunc	=function() return BUI.Vars.FrameShowMax end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('FrameShowMax', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Show Percents
	{	type		="checkbox",
		name		="FramePercents",
		getFunc	=function() return BUI.Vars.FramePercents end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('FramePercents', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Unit Frame Width
	{	type		="slider",
		name		="FrameWidth",
		min		=200,
		max		=500,
		step		=10,
		getFunc	=function() return BUI.Vars.FrameWidth end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("FrameWidth", value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Unit Frame Height
	{	type		="slider",
		name		="FrameHeight",
		min		=16,
		max		=40,
		step		=2,
		getFunc	=function() return BUI.Vars.FrameHeight end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("FrameHeight", value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Frame Font Size
	{	type		="slider",
		name		="FrameFontSize",
		min		=8,
		max		=24,
		step		=1,
		getFunc	=function() return BUI.Vars.FrameFontSize end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("FrameFontSize", value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Display Nameplate
	{	type		="checkbox",
		name		="EnableNameplate",
		getFunc	=function() return BUI.Vars.EnableNameplate end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('EnableNameplate', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Food buff
	{	type		="checkbox",
		name		="FoodBuff",
		getFunc	=function() return BUI.Vars.FoodBuff end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('FoodBuff', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Reset Unit Frames
	{	type		="button",
		name		="FramesReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("FramesResetDesc"),func=function()BUI.Menu.Reset("Frames")end})end,
	},
	--	==Curved Frames==
	{type="submenu",name="CurvedHeader",controls={
	--Curved Frames Style
	{	type		="dropdown",
		name		="CurvedFrame",
		choices	={"Disabled","Simple","Cone","Blades"},
		getFunc	=function() return BUI.Vars.CurvedFrame+1 end,
		setFunc	=function(i,value) BUI.Vars.CurvedFrame=i-1 BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
	},
	--Curved Frames Distance
	{	type		="slider",
		name		="CurvedDistance",
		min		=80,
		max		=800,
		step		=20,
		getFunc	=function() return BUI.Vars.CurvedDistance end,
		setFunc	=function(value) BUI.Vars.CurvedDistance=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		warning	="CurvedDistanceWarn",
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames offset
	{	type		="slider",
		name		="CurvedOffset",
		min		=-300,
		max		=300,
		step		=50,
		getFunc	=function() return BUI.Vars.CurvedOffset end,
		setFunc	=function(value) BUI.Vars.CurvedOffset=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames height
	{	type		="slider",
		name		="CurvedHeight",
		min		=80,
		max		=640,
		step		=20,
		getFunc	=function() return BUI.Vars.CurvedHeight end,
		setFunc	=function(value) BUI.Vars.CurvedHeight=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames Depth
	{	type		="slider",
		name		="CurvedDepth",
		min		=50,
		max		=100,
		step		=10,
		getFunc	=function() return BUI.Vars.CurvedDepth*100 end,
		setFunc	=function(value) BUI.Vars.CurvedDepth=value/100 BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Stat Values
	{	type		="checkbox",
		name		="CurvedStatValues",
		getFunc	=function() return BUI.Vars.CurvedStatValues end,
		setFunc	=function(value) BUI.Vars.CurvedStatValues=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Deadly hit animation
	{	type		="checkbox",
		name		="CurvedHitAnimation",
		getFunc	=function() return BUI.Vars.CurvedHitAnimation end,
		setFunc	=function(value) BUI.Vars.CurvedHitAnimation=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Attributes shift
	{	type		="checkbox",
		name		="CurvedShift",
		getFunc	=function() return BUI.Vars.CurvedShift end,
		setFunc	=function(value) BUI.Vars.CurvedShift=value BUI.Curved.OnCombatState(false) BUI_CurvedTarget:SetAlpha(BUI.Vars.FrameOpacityIn/100) BUI_CurvedTarget:SetHidden(value) end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Shift animation
	{	type		="checkbox",
		name		="CurvedShiftAnimation",
		getFunc	=function() return BUI.Vars.CurvedShiftAnimation end,
		setFunc	=function(value) BUI.Vars.CurvedShiftAnimation=value if value then BUI.Curved.OnCombatState(false) end end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 or not BUI.Vars.CurvedShift end,
	},
	--Reset Curved Frames
	{
		type		="button",
		name		="CurvedReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("CurvedResetDesc"),func=function()BUI.Menu.Reset("Curved")end})end,
	}}},
	--	=="Advanced settings==
	{type="submenu",name="AdvancedHeader",controls={
	--Experience Bar
	{	type		="checkbox",
		name		="EnableXPBar",
		getFunc	=function() return BUI.Vars.EnableXPBar end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('EnableXPBar', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame and BUI.Vars.CurvedFrame==0 end,
	},
	--Bound Armaments/Grim Focus
	{	type		="checkbox",
		name		="ShowDots",
		getFunc	=function() return BUI.Vars.ShowDots end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('ShowDots', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame and BUI.Vars.CurvedFrame==0 end,
	},
	--Dodge fatigue
	{	type		="checkbox",
		name		="DodgeFatigue",
		getFunc	=function() return BUI.Vars.DodgeFatigue end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('DodgeFatigue', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame and BUI.Vars.CurvedFrame==0 end,
	},
	--Auto hide
	{	type		="checkbox",
		name		="FramesFade",
		getFunc	=function() return BUI.Vars.FramesFade end,
		setFunc	=function(value) BUI.Vars.FramesFade=value end,
		disabled	=function() return not BUI.Vars.PlayerFrame and BUI.Vars.CurvedFrame==0 end,
	},
	--Shield bar
	{	type		="checkbox",
		name		="Shield",
		getFunc	=function() return BUI.Vars.Shield end,
		setFunc	=function(value) BUI.Vars.Shield=value end,
	},
	--Trauma bar
	{	type		="checkbox",
		name		="Trauma",
		getFunc	=function() return BUI.Vars.Trauma end,
		setFunc	=function(value) BUI.Vars.Trauma=value end,
	}}}
	}
	MenuPanel["MenuPlayerFrames"]={name="PlayerHeader"}
	MenuHandlers["MenuPlayerFrames"]={
	["OnEffectivelyShown"]=BUI.Menu.FramesReposition,
	["OnEffectivelyHidden"]=function() BUI.Menu.FramesRestore() BUI.inMenu=false end,
	}
--[[
	MenuOptions["MenuCurvedFrames"]={
	--	type="header", name="CurvedHeader", curved=true
	--Curved Frames Style
	{	type		="dropdown",
		name		="CurvedFrame",
		choices	={"Disabled","Simple","Cone","Blades"},
		getFunc	=function() return BUI.Vars.CurvedFrame+1 end,
		setFunc	=function(i,value) BUI.Vars.CurvedFrame=i-1 BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
	},
	--Curved Frames Distance
	{	type		="slider",
		name		="CurvedDistance",
		min		=80,
		max		=800,
		step		=20,
		getFunc	=function() return BUI.Vars.CurvedDistance end,
		setFunc	=function(value) BUI.Vars.CurvedDistance=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		warning	="CurvedDistanceWarn",
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames offset
	{	type		="slider",
		name		="CurvedOffset",
		min		=-300,
		max		=300,
		step		=50,
		getFunc	=function() return BUI.Vars.CurvedOffset end,
		setFunc	=function(value) BUI.Vars.CurvedOffset=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames height
	{	type		="slider",
		name		="CurvedHeight",
		min		=80,
		max		=640,
		step		=20,
		getFunc	=function() return BUI.Vars.CurvedHeight end,
		setFunc	=function(value) BUI.Vars.CurvedHeight=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Frames Depth
	{	type		="slider",
		name		="CurvedDepth",
		min		=10,
		max		=100,
		step		=10,
		getFunc	=function() return BUI.Vars.CurvedDepth*100 end,
		setFunc	=function(value) BUI.Vars.CurvedDepth=value/100 BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Curved Stat Values
	{	type		="checkbox",
		name		="CurvedStatValues",
		getFunc	=function() return BUI.Vars.CurvedStatValues end,
		setFunc	=function(value) BUI.Vars.CurvedStatValues=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Deadly hit animation
	{	type		="checkbox",
		name		="CurvedHitAnimation",
		getFunc	=function() return BUI.Vars.CurvedHitAnimation end,
		setFunc	=function(value) BUI.Vars.CurvedHitAnimation=value BUI.Curved.Initialize() BUI.Menu.FramesReposition() end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Attributes shift
	{	type		="checkbox",
		name		="CurvedShift",
		getFunc	=function() return BUI.Vars.CurvedShift end,
		setFunc	=function(value) BUI.Vars.CurvedShift=value BUI.Curved.OnCombatState(false) BUI_CurvedTarget:SetAlpha(BUI.Vars.FrameOpacityIn/100) BUI_CurvedTarget:SetHidden(value) end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Shift animation
	{	type		="checkbox",
		name		="CurvedShiftAnimation",
		getFunc	=function() return BUI.Vars.CurvedShiftAnimation end,
		setFunc	=function(value) BUI.Vars.CurvedShiftAnimation=value if value then BUI.Curved.OnCombatState(false) end end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 or not BUI.Vars.CurvedShift end,
	},
	--Auto hide
	{	type		="checkbox",
		name		="FramesFade",
		getFunc	=function() return BUI.Vars.FramesFade end,
		setFunc	=function(value) BUI.Vars.FramesFade=value end,
		disabled	=function() return BUI.Vars.CurvedFrame==0 end,
	},
	--Reset Curved Frames
	{
		type		="button",
		name		="CurvedReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("CurvedResetDesc"),func=function()BUI.Menu.Reset("Curved")end})end,
	}}
	MenuPanel["MenuCurvedFrames"]={name="CurvedHeader"}
	MenuHandlers["MenuCurvedFrames"]={
	["OnEffectivelyShown"]=BUI.Menu.FramesReposition,
	["OnEffectivelyHidden"]=function() BUI.Menu.FramesRestore() BUI.inMenu=false end,
	}
--]]
	MenuOptions["MenuTargetFrames"]={
--		type="submenu", name="TargetHeader", controls={
	--Execute Threshold
	{	type		="slider",
		name		="ExecuteThreshold",
		min		=0,
		max		=50,
		step		=5,
		getFunc	=function() return BUI.Vars.ExecuteThreshold end,
		setFunc	=function(value) BUI.Vars.ExecuteThreshold=value end,
	},
	--Execute Sound
	{	type		="checkbox",
		name		="ExecuteSound",
		getFunc	=function() return BUI.Vars.ExecuteSound end,
		setFunc	=function(value) BUI.Vars.ExecuteSound=value end,
	},
	--Default Target Frame
	{	type		="header", name="DefaultTargetFrame"},
	{	type		="checkbox",
		name		="DefaultTargetFrame",
		getFunc	=function() return BUI.Vars.DefaultTargetFrame end,
		setFunc	=function(value)
			BUI.Vars.DefaultTargetFrame=value
			if value then SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI) return end
			BUI.SwitchUnitFramesEvents()
		end,
		warning	="ReloadUiWarn4",
	},
	{	type		="checkbox",
		name		="DefaultTargetFrameText",
		getFunc	=function() return BUI.Vars.DefaultTargetFrameText end,
		setFunc	=function(value) BUI.Vars.DefaultTargetFrameText=value end,
		disabled	=function() return not BUI.Vars.DefaultTargetFrame end
	},
	--Additional Target Frame
	{	type		="header", name="TargetFrame"},
	{	type		="checkbox",
		name		="TargetFrame",
		getFunc	=function() return BUI.Vars.TargetFrame end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('TargetFrame', value) end,
	},
	--Target Frame Width
	{	type		="slider",
		name		="TargetWidth",
		min		=200,
		max		=500,
		step		=20,
		getFunc	=function() return BUI.Vars.TargetWidth end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("TargetWidth", value) end,
		disabled	=function() return not BUI.Vars.TargetFrame end,
	},
	--Target Frame Height
	{	type		="slider",
		name		="TargetHeight",
		min		=16,
		max		=40,
		step		=10,
		getFunc	=function() return BUI.Vars.TargetHeight end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("TargetHeight", value) end,
		disabled	=function() return not BUI.Vars.TargetFrame end,
	},
	--Center Frame Text
	{	type		="checkbox",
		name		="TargetFrameCenter",
		getFunc	=function() return BUI.Vars.TargetFrameCenter end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('TargetFrameCenter', value) end,
		disabled	=function() return not BUI.Vars.PlayerFrame end,
	},
	--Show Percents
	{	type		="checkbox",
		name		="TargetFramePercents",
		getFunc	=function() return BUI.Vars.TargetFramePercents end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('TargetFramePercents', value) end,
		disabled	=function() return not BUI.Vars.TargetFrame end,
	},
	--Boss Frame
	{	type		="header", name="BossFrame"},
	{	type		="checkbox",
		name		="BossFrame",
		getFunc	=function() return BUI.Vars.BossFrame end,
		setFunc	=function(value) BUI.Vars.BossFrame=value if BUI_BossFrame==nil then BUI.Frames.Bosses_UI() end BUI_BossFrame:SetHidden(not BUI.Vars.BossFrame) end,
	},
	--Boss Frame Width
	{	type		="slider",
		name		="BossWidth",
		min		=180,
		max		=360,
		step		=20,
		getFunc	=function() return BUI.Vars.BossWidth end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("BossWidth", value) end,
		disabled	=function() return not BUI.Vars.BossFrame end,
	},
	--Boss Frame Height
	{	type		="slider",
		name		="BossHeight",
		min		=20,
		max		=80,
		step		=2,
		getFunc	=function() return BUI.Vars.BossHeight end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("BossHeight", value) end,
		disabled	=function() return not BUI.Vars.BossFrame end,
	},
	--Reset Unit Frames
	{	type		="button",
		name		="FramesReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("FramesResetDesc"),func=function()BUI.Menu.Reset("Frames")end})end,
	}}
	MenuPanel["MenuTargetFrames"]={name="TargetHeader"}
	MenuHandlers["MenuTargetFrames"]={
	["OnEffectivelyShown"]=BUI.Menu.FramesReposition,
	["OnEffectivelyHidden"]=function() BUI.Menu.FramesRestore() BUI.inMenu=false end,
	}

	MenuOptions["MenuAttackersFrames"]={
	{	type		="checkbox",
		name		="Attackers",
		getFunc	=function() return BUI.Vars.Attackers end,
		setFunc	=function(value) BUI.Vars.Attackers=value BUI_Attackers:SetHidden(not BUI.Vars.Attackers) end,
	},
	--Attackers Frame Width
	{	type		="slider",
		name		="AttackersWidth",
		min		=180,
		max		=360,
		step		=20,
		getFunc	=function() return BUI.Vars.AttackersWidth end,
		setFunc	=function(value) BUI.Vars.AttackersWidth=value BUI.Damage.Attackers_UI() end,
		disabled	=function() return not BUI.Vars.Attackers end,
	},
	--Attackers Frame Height
	{	type		="slider",
		name		="AttackersHeight",
		min		=20,
		max		=80,
		step		=2,
		getFunc	=function() return BUI.Vars.AttackersHeight end,
		setFunc	=function(value) BUI.Vars.AttackersHeight=value BUI.Damage.Attackers_UI() end,
		disabled	=function() return not BUI.Vars.Attackers end,
	}}
	MenuPanel["MenuAttackersFrames"]={name="Attackers"}
	MenuHandlers["MenuAttackersFrames"]={
	["OnEffectivelyShown"]=function()
		BUI.inMenu=true
		if BUI.Vars.Attackers then
			BUI_Attackers:SetHidden(false)
			BUI_Attackers[1]:SetHidden(false)
		end
		SatuveUI:SetHidden(false)
	end,
	["OnEffectivelyHidden"]=function()
		if BUI.Vars.Attackers then
			BUI_Attackers:SetHidden(true)
		end
		BUI.inMenu=false
	end,
	}

	-- GroupFrames, Damage Statistics and Buffs menus intentionally removed.

	MenuOptions["MenuActions"]={
	--	type="submenu",name="ActionsHeader",controls={
	{	type		="checkbox",
		name		="Actions",
		getFunc	=function() return BUI.Vars.Actions end,
		setFunc	=function(value) BUI.Vars.Actions=value BUI.Actions:Initialize() end,
	},
	{	type		="slider",
		name		="UpdateTime",
		min		=1,
		max		=10,
		step	=1,
		getFunc	=function() return BUI.Vars.UpdateTime/100 end,
		setFunc	=function(value) BUI.Vars.UpdateTime=value*100 BUI.Actions:Initialize() BUI.Buffs.Initialize() end
	},
	{
		type		="checkbox",
		name		="ActionsPrecise",
		getFunc	=function() return BUI.Vars.ActionsPrecise end,
		setFunc	=function(value) BUI.Vars.ActionsPrecise=value BUI.Actions:Initialize() end,
--		warning	="PerformanceWarn",
		disabled	=function() return not BUI.Vars.Actions end,
	},
	{
		type		="checkbox",
		name		="UseSwapPanel",
		getFunc	=function() return BUI.Vars.UseSwapPanel end,
		setFunc	=function(value) BUI.Vars.UseSwapPanel=value BUI.Actions:Initialize() end,
		disabled	=function() return not BUI.Vars.Actions end,
	},
	{
		type		="checkbox",
		name		="HideSwapPanel",
		getFunc	=function() return BUI.Vars.HideSwapPanel end,
		setFunc	=function(value) BUI.Vars.HideSwapPanel=value end,
		disabled	=function() return not BUI.Vars.Actions or not BUI.Vars.UseSwapPanel end,
	},
	{
		type		="checkbox",
		name		="FullSwapPanel",
		getFunc	=function() return BUI.Vars.FullSwapPanel end,
		setFunc	=function(value) BUI.Vars.FullSwapPanel=value end,
		disabled	=function() return not BUI.Vars.Actions or not BUI.Vars.UseSwapPanel end,
	},
	{	type		="checkbox",
		name		="ExpiresAnimation",
		getFunc	=function() return BUI.Vars.ExpiresAnimation end,
		setFunc	=function(value) BUI.Vars.ExpiresAnimation=value end,
		disabled	=function() return not BUI.Vars.Actions end,
	},
	{	type		="slider",
		name		="ActionsFontSize",
		min		=12,
		max		=20,
		step		=1,
		getFunc	=function() return BUI.Vars.ActionsFontSize end,
		setFunc	=function(value) BUI.Vars.ActionsFontSize=value BUI.Actions:Initialize() end,
		disabled	=function() return not BUI.Vars.Actions end,
	},
	--Proc Animation
	{	type		="checkbox",
		name		="ProcAnimation",
		getFunc	=function() return BUI.Vars.ProcAnimation end,
		setFunc	=function(value) BUI.Vars.ProcAnimation=value end,
		disabled	=function() return not BUI.Vars.Actions end,
		warning	="ReloadUiWarn"
	},
	--Proc Sound
	{	type		="dropdown",
		name		="ProcSound",
		choices	=ProcSounds,
		getFunc	=function() return BUI.Vars.ProcSound end,
		setFunc	=function(i,value) BUI.Vars.ProcSound=value PlaySound(value) end,
		disabled	=function() return not BUI.Vars.Actions or not BUI.Vars.ProcAnimation end,
	},
	--Reset
	{	type		="button",
		name		="ActionsReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("ActionsResetDesc"),func=function()BUI.Menu.Reset("Actions")end})end,
	}}
	MenuPanel["MenuActions"]={name="ActionsHeader"}
	MenuHandlers["MenuActions"]={
	["OnEffectivelyHidden"]=function() BUI.inMenu=false end,
	}

	MenuOptions["MenuNotifications"]={
	--	type="submenu", name="NotHeader", controls={
	--Food
	{	type		="checkbox",
		name		="NotificationFood",
		getFunc	=function() return BUI.Vars.NotificationFood end,
		setFunc	=function(value) BUI.Vars.NotificationFood=value end,
	},
	--Effect visualisation
	{	type		="checkbox",
		name		="EffectVisualisation",
		getFunc	=function() return BUI.Vars.EffectVisualisation end,
		setFunc	=function(value) BUI.Vars.EffectVisualisation=value BUI.OnScreen:Initialize() end,
	},
	--Font Size
	{	type		="slider",
		name		="NotificationsSize",
		min		=24,
		max		=40,
		step		=2,
		getFunc	=function() return BUI.Vars.NotificationsSize end,
		setFunc	=function(value) BUI.Vars.NotificationsSize=value BUI.OnScreen.UI_Init() end,
		advanced	=false
	},
	{	type		="header",name="NotificationsGroup"},
	--Group Notifications
	{	type		="checkbox",
		name		="NotificationsGroup",
		getFunc	=function() return BUI.Vars.NotificationsGroup end,
		setFunc	=function(value) BUI.Vars.NotificationsGroup=value BUI.OnScreen:Initialize() end,
	},
	--Healer or Tank death
	{	type		="checkbox",
		name		="OnScreenPriorDeath",
		getFunc	=function() return BUI.Vars.OnScreenPriorDeath end,
		setFunc	=function(value) BUI.Vars.OnScreenPriorDeath=value end,
	},
	{	type		="header",name="NotificationsCombatHeader"},
	--World Notifications
	{	type		="checkbox",
		name		="NotificationsWorld",
		getFunc	=function() return BUI.Vars.NotificationsWorld end,
		setFunc	=function(value) BUI.Vars.NotificationsWorld=value BUI.OnScreen:Initialize() end,
	},
	--Trial Notifications
	{	type		="checkbox",
		name		="NotificationsTrial",
		getFunc	=function() return BUI.Vars.NotificationsTrial end,
		setFunc	=function(value) BUI.Vars.NotificationsTrial=value BUI.OnScreen:Initialize() end,
	},
	--Sound
	{	type		="dropdown",
		name		="NotificationSound_1",
		choices	=NotificationSounds,
		getFunc	=function() return BUI.Vars.NotificationSound_1 end,
		setFunc	=function(i,value) BUI.Vars.NotificationSound_1=value PlaySound(value) end,
		disabled	=function() return not BUI.Vars.NotificationsTrial and not BUI.Vars.NotificationsWorld end,
	},
	--Sound
	{	type		="dropdown",
		name		="NotificationSound_2",
		choices	=NotificationSounds,
		getFunc	=function() return BUI.Vars.NotificationSound_2 end,
		setFunc	=function(i,value) BUI.Vars.NotificationSound_2=value PlaySound(value) end,
		disabled	=function() return not BUI.Vars.NotificationsTrial and not BUI.Vars.NotificationsWorld end,
	},
--[[
	--PvP Notifications
	{	type		="checkbox",
		name		="NotificationsPvP",
		getFunc	=function() return BUI.Vars.NotificationsPvP end,
		setFunc	=function(value) BUI.Vars.NotificationsPvP=value BUI.OnScreen:Initialize() end,
	},
	--Notifications Timer
	{	type		="slider",
		name		="NotificationsTimer",
		min		=1000,
		max		=8000,
		step		=1000,
		getFunc	=function() return BUI.Vars.NotificationsTimer end,
		setFunc	=function(value) BUI.Vars.NotificationsTimer=value end,
	},
	--Glyphs
	{	type		="checkbox",
		name		="Glyphs",
		getFunc	=function() return BUI.Vars.Glyphs end,
		setFunc	=function(value) BUI.Vars.Glyphs=value end,
	}
--]]
	}
	MenuPanel["MenuNotifications"]={name="NotificationsHeader"}
	MenuHandlers["MenuNotifications"]={
	["OnEffectivelyHidden"]=function() BUI.inMenu=false end,
	}

	MenuOptions["MenuFrameColors"]={
	--	type="header",name="ColorsHeader"
	--Name
	{	type		="dropdown",
		name		="FrameNameFormat",
		choices	={"Name","@AccName","Name@AccName"},
		getFunc	=function() return BUI.Vars.FrameNameFormat end,
		setFunc	=function(i,value) BUI.Vars.FrameNameFormat=i BUI.Menu.UpdateFrames() end,
	},
	--Primary Frame Font
	{	type		="dropdown",
		name		="FrameFont1",
		choices	={"Metamorphous", "ESO Standard", "ESO Bold", "Prose Antique", "Handwritten", "Trajan Pro", "Futura Standard", "Futura Bold", "Gamepad Standard", "Gamepad Bold"},
		getFunc	=function() return BUI.TranslateFont(BUI.Vars.FrameFont1) end,
		setFunc	=function(i,value) BUI.Menu.UpdateFrames("FrameFont1", BUI.TranslateFont(value)) end,
	},
	--Secondary Frame Font
	{	type		="dropdown",
		name		="FrameFont2",
		choices	={"Metamorphous", "ESO Standard", "ESO Bold", "Prose Antique", "Handwritten", "Trajan Pro", "Futura Standard", "Futura Bold", "Gamepad Standard", "Gamepad Bold"},
		getFunc	=function() return BUI.TranslateFont(BUI.Vars.FrameFont2) end,
		setFunc	=function(i,value) BUI.Menu.UpdateFrames("FrameFont2", BUI.TranslateFont(value)) end,
	},
	{	type		="checkbox",
		name		="DecimalValues",
		getFunc	=function() return BUI.Vars.DecimalValues end,
		setFunc	=function(value) BUI.Vars.DecimalValues=value end,
	},
	--In-Combat Opacity
	{	type		="slider",
		name		="FrameOpacityIn",
		min		=0,
		max		=100,
		step		=10,
		getFunc	=function() return BUI.Vars.FrameOpacityIn end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("FrameOpacityIn", value) end,
	},
	--Non-Combat Opacity
	{	type		="slider",
		name		="FrameOpacityOut",
		min		=0,
		max		=100,
		step		=10,
		getFunc	=function() return BUI.Vars.FrameOpacityOut end,
		setFunc	=function(value) BUI.Menu.UpdateFrames("FrameOpacityOut", value) end,
	},
	{type="header",name="AttributeColors"},
	--Health Bar Color
	{	type		="gradient",
		name		="FrameHealthColor",
		getFunc	=function() return BUI.Vars.FrameHealthColor[1],BUI.Vars.FrameHealthColor[2],BUI.Vars.FrameHealthColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameHealthColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
		getFunc2	=function() return BUI.Vars.FrameHealthColor1[1],BUI.Vars.FrameHealthColor1[2],BUI.Vars.FrameHealthColor1[3] end,
		setFunc2	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameHealthColor1', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
	},
	--Magicka Bar Color
	{	type		="gradient",
		name		="FrameMagickaColor",
		getFunc	=function() return BUI.Vars.FrameMagickaColor[1],BUI.Vars.FrameMagickaColor[2],BUI.Vars.FrameMagickaColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameMagickaColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
		getFunc2	=function() return BUI.Vars.FrameMagickaColor1[1],BUI.Vars.FrameMagickaColor1[2],BUI.Vars.FrameMagickaColor1[3] end,
		setFunc2	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameMagickaColor1', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
	},
	--Stamina Bar Color
	{	type		="gradient",
		name		="FrameStaminaColor",
		getFunc	=function() return BUI.Vars.FrameStaminaColor[1],BUI.Vars.FrameStaminaColor[2],BUI.Vars.FrameStaminaColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameStaminaColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
		getFunc2	=function() return BUI.Vars.FrameStaminaColor1[1],BUI.Vars.FrameStaminaColor1[2],BUI.Vars.FrameStaminaColor1[3] end,
		setFunc2	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameStaminaColor1', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
	},
	--Shield Bar Colors
	{	type		="gradient",
		name		="FrameShieldColor",
		getFunc	=function() return BUI.Vars.FrameShieldColor[1],BUI.Vars.FrameShieldColor[2],BUI.Vars.FrameShieldColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameShieldColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
		getFunc2	=function() return BUI.Vars.FrameShieldColor1[1],BUI.Vars.FrameShieldColor1[2],BUI.Vars.FrameShieldColor1[3] end,
		setFunc2	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameShieldColor1', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
	},
	--Trauma Bar Colors
	{	type		="gradient",
		name		="FrameTraumaColor",
		getFunc	=function() return BUI.Vars.FrameTraumaColor[1],BUI.Vars.FrameTraumaColor[2],BUI.Vars.FrameTraumaColor[3] end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameTraumaColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
		getFunc2	=function() return BUI.Vars.FrameTraumaColor[1],BUI.Vars.FrameTraumaColor[2],BUI.Vars.FrameTraumaColor[3] end,
		setFunc2	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameTraumaColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100,1}) end,
	},
	{	type		="button",
		name		="SameColors",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("SameColorsDesc"),func=function()BUI.Menu.Reset("SameColors")end})end,
	},
	{type="header",name="GroupRolesHeader"},	--Group Roles
	--Self Color difference
	{	type		="checkbox",
		name		="SelfColor",
		getFunc	=function() return BUI.Vars.SelfColor end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('SelfColor', value) end,
	},
	--Colorize Roles
	{	type		="checkbox",
		name		="ColorRoles",
		getFunc	=function() return BUI.Vars.ColorRoles end,
		setFunc	=function(value) BUI.Menu.UpdateFrames('ColorRoles', value) end,
	},
	--Tank Role Color
	{	type		="colorpicker",
		name		="FrameTankColor",
		getFunc	=function() return unpack(BUI.Vars.FrameTankColor) end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameTankColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100}) end,
		disabled	=function() return not BUI.Vars.ColorRoles end,
	},
	--Healer Role Color
	{	type		="colorpicker",
		name		="FrameHealerColor",
		getFunc	=function() return unpack(BUI.Vars.FrameHealerColor) end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameHealerColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100}) end,
		disabled	=function() return not BUI.Vars.ColorRoles end,
	},
	--DD Role Color
	{	type		="colorpicker",
		name		="FrameDamageColor",
		getFunc	=function() return unpack(BUI.Vars.FrameDamageColor) end,
		setFunc	=function(r,g,b,a) BUI.Menu.UpdateFrames('FrameDamageColor', {math.floor(r*100)/100, math.floor(g*100)/100, math.floor(b*100)/100}) end,
		disabled	=function() return not BUI.Vars.ColorRoles end,
	},
	--Reset Colors
	{	type		="button",
		name		="ColorsReset",
		func		=function()ZO_Dialogs_ShowDialog("BUI_RESET_CONFIRMATION", {text=BUI.Loc("ColorsResetDesc"),func=function()BUI.Menu.Reset("Colors")end})end,
	}}
	MenuPanel["MenuFrameColors"]={name="ColorsHeader"}
	MenuHandlers["MenuFrameColors"]={
	["OnEffectivelyShown"]=BUI.Menu.FramesReposition,
	["OnEffectivelyHidden"]=function() BUI.Menu.FramesRestore() BUI.inMenu=false end,
	}

	MenuOptions["MenuMeters"]={
	{	type		="checkbox",
		name		="Meter_Speed",
		getFunc	=function() return BUI.Vars.Meter_Speed end,
		setFunc	=function(value) BUI.Vars.Meter_Speed=value BUI.Meters.Initialize() end,
	},
	{	type		="checkbox",
		name		="Meter_Power",
		getFunc	=function() return BUI.Vars.Meter_Power end,
		setFunc	=function(value) BUI.Vars.Meter_Power=value BUI.Meters.Initialize() end,
	},
	{	type		="checkbox",
		name		="Meter_Crit",
		getFunc	=function() return BUI.Vars.Meter_Crit end,
		setFunc	=function(value) BUI.Vars.Meter_Crit=value BUI.Meters.Initialize() end,
	},
	{	type		="checkbox",
		name		="Meter_Exp",
		getFunc	=function() return BUI.Vars.Meter_Exp end,
		setFunc	=function(value) BUI.Vars.Meter_Exp=value BUI.Meters.Initialize() end,
	},
	{	type		="checkbox",
		name		="Meter_DPS",
		getFunc	=function() return BUI.Vars.Meter_DPS end,
		setFunc	=function(value) BUI.Vars.Meter_DPS=value BUI.Meters.Initialize() end,
	},
	{	type		="checkbox",
		name		="Meter_Criminal",
		getFunc	=function() return BUI.Vars.Meter_Criminal end,
		setFunc	=function(value) BUI.Vars.Meter_Criminal=value BUI.Meters.Initialize() end,
	},
	{	type		="slider",
		name		="Meter_Scale",
		min		=80,
		max		=200,
		step		=10,
		getFunc	=function() return BUI.Vars.Meter_Scale or BUI.Meters.Default.Meter_Scale end,
		setFunc	=function(value) BUI.Vars.Meter_Scale=value BUI.Meters.Initialize() end,
	}}
	MenuPanel["MenuMeters"]={name="Meters_Header"}
	MenuHandlers["MenuMeters"]={
	["OnEffectivelyShown"]=function()
		BUI.inMenu=true
		SatuveUI:SetHidden(false)
	end,
	["OnEffectivelyHidden"]=function()
		BUI.inMenu=false
	end,
	}

end

function BUI.Menu.MakeList(var)
	local fs=18
	local data,options,values={},{},{}
	for id,value in pairs(var) do
		if value then
			table.insert(data,{type(id)=="number" and GetAbilityName(id) or id,id})
		end
	end
	table.sort(data,function(a,b) return a[1]<b[1] end)
	for i,value in ipairs(data) do
		options[i]=type(value[2])=="number" and zo_iconFormat(GetAbilityIcon(value[2]),fs,fs).."["..value[2].."] "..value[1] or value[1]
		values[i]=value[2]
	end
	return options,values
end

function BUI.Menu.MakeBuffsList()
	local fs=18
	local options,values={},{}
	local i=0
	for name,data in pairs(BUI.Stats.Current[BUI.ReportN].PlayerBuffs) do
		if name then
			i=i+1
			options[i]=zo_iconFormat(GetAbilityIcon(data.id),fs,fs).."["..data.id.."] "..name
			values[i]=data.id
		end
	end
	return options,values
end

function BUI.Menu.Initialize()
	if BUI.init.Menu then return true end
	local AdvancedMenu=true
	--Setup the menu
	MenuOptions_Init()

	-- Build the option pages first. With LAM/LibGamepad we expose ONE panel named
	-- "Bandit UI" and place all former pages below it as submenus. The legacy BUI
	-- menu is kept unchanged as the fallback when LAM is not installed.
	local prepared={}
	for index,data in pairs(MenuOptions) do
		if index ~= "MenuAttackersFrames" and index ~= "MenuMeters" then
		local Options={}
		for i=1, #data do
			if not data[i].advanced or AdvancedMenu then
				if data[i].type=="submenu" then
					local controls={}
					for j=1, #data[i].controls do
						if (not data[i].controls[j].advanced or AdvancedMenu) and (not data[i].controls[j].curved or(data[i].controls[j].curved and BUI.Vars.CurvedFrame~="Disabled")) then
							table.insert(controls, data[i].controls[j])
						end
					end
					table.insert(Options, {["type"]="submenu",["name"]=data[i].name,["controls"]=controls})
				else
					table.insert(Options, data[i])
				end
			end
		end

		local pageName=MenuNumber[index].."|t32:32:"..MenuIcon[index].."|t"..BUI.Loc(MenuPanel[index].name)
		table.insert(prepared, {
			index=index,
			name=pageName,
			options=Options,
			order=tonumber(string.match(MenuNumber[index] or "999", "%d+")) or 999,
		})
		end -- hidden LAM categories
	end

    -- Off Balance Tracker is integrated as a normal My UI section.
    -- The original options retain their effect tracking, color, sound and role logic.
    if OffBalanceTracker and OffBalanceTracker.CreateSettings and OffBalanceTracker.SV then
        local obtOptions=OffBalanceTracker.CreateSettings()
        if obtOptions then
            table.insert(prepared,{
                index="MyUIOffBalance", name="14.  Off Balance Tracker",
                options=obtOptions, order=14,
                noLegacyPanel=true,
            })
        end
    end

	table.sort(prepared,function(a,b)
		if a.order==b.order then return a.index<b.index end
		return a.order<b.order
	end)

	local useGroupedLAM=BUI.SettingsBridge and BUI.SettingsBridge.Available and BUI.SettingsBridge.Available() and BUI.SettingsBridge.RegisterGrouped
	if useGroupedLAM then
		local sections={}
		for _,entry in ipairs(prepared) do
			table.insert(sections,{id=entry.index,name=entry.name,options=entry.options,order=entry.order})
		end
		BUI.SettingsBridge.RegisterGrouped("BUI_BanditUI",{
			name="My UI",
			displayName="My UI",
			author="Satuve",
			version=tostring(BUI.Version or ""),
		},sections)
	end

	-- Keep the original Bandit window complete as a mouse/keyboard fallback too.
	-- Previously, enabling the grouped LAM path skipped these pages, leaving only
	-- the separately-created 2/9/18/20 pages in the old window.
	for _,entry in ipairs(prepared) do
        if not entry.noLegacyPanel then
		local index=entry.index
		MenuPanel[index].name=entry.name
		local panel=BUI.Menu.RegisterPanel("BUI_"..index, MenuPanel[index])
		BUI.Menu.RegisterOptions("BUI_"..index, entry.options)
		if MenuHandlers[index] and panel and panel.SetHandler then
			for event,handler in pairs(MenuHandlers[index]) do panel:SetHandler(event, handler) end
		end
        end
	end
	BUI.init.Menu=true
end

function BUI.Menu:FramesReposition()
	BUI.inMenu=true
	--Unit Frames Display
	if BUI.init.Frames then
		if BUI.Vars.TargetFrame then
			BUI_TargetFrame:SetHidden(false)
		end
		if BUI.Vars.PlayerFrame then
			--Show the player frame
			if not BUI.Vars.FrameHorisontal then
				BUI_PlayerFrame:ClearAnchors()
				BUI_PlayerFrame:SetAnchor(LEFT,BUI_MenuPlayerFrames,RIGHT,20,0)
			end
			BUI_PlayerFrame_Base:SetHidden(false)
			BUI_PlayerFrame_Base:SetAlpha(BUI.Vars.FrameOpacityIn/100)
			BUI.Frames.Regen('player',3,nil,2000) BUI.Frames.Regen('player',4,nil,2000)
			if BUI_TargetFrame then
				BUI_TargetFrame:SetHidden(false)
				BUI.Frames.Regen('reticleover',3,nil,2000) BUI.Frames.Regen('reticleover',4,nil,2000)
			end
		end
		if BUI.Vars.CurvedFrame~=0 then
			BUI.Curved.Initialize()
			BUI_Curved:ClearAnchors()
			BUI_Curved:SetAnchor(CENTER,BUI_MenuPlayerFrames,RIGHT,300,BUI.Vars.CurvedOffset)
			BUI.Curved.Regen('player',3,nil,2000) BUI.Curved.Regen('player',4,nil,2000)
			BUI_Curved_Alt:SetHidden(false)
			BUI_Curved:SetAlpha(BUI.Vars.FrameOpacityIn/100)
			BUI_CurvedTarget:ClearAnchors()
			BUI_CurvedTarget:SetAnchor(CENTER,BUI_MenuPlayerFrames,RIGHT,300,BUI.Vars.CurvedOffset)

			--Spoof a shield
			BUI.Curved.Shield('player',math.floor(BUI.Player.health.max*.5),BUI.Player.health.pct,BUI.Player.health.max,BUI.Player.trauma.current)
			BUI.Curved.Trauma('player',math.floor(BUI.Player.health.max*.25),BUI.Player.health.pct,BUI.Player.health.max,BUI.Player.shield.current)

			if not BUI.Vars.CurvedShift then
				BUI_CurvedTarget:SetHidden(false)
				BUI_CurvedTarget:SetAlpha(BUI.Vars.FrameOpacityIn/100)
				BUI.Curved.Regen('reticleover',3,nil,2000) BUI.Curved.Regen('reticleover',4,nil,2000)
			end
		end
		if BUI.Vars.BossFrame then
			if BUI.Frame["boss1"] then BUI.Frame["boss1"]:SetHidden(false) end
		end
	end
	--Spoof a shield on the player frame
	BUI.Player:UpdateShield('player', math.floor(BUI.Player.health.max*.5),	BUI.Player.health.max)
	--Spoof trauma on the player frame
	BUI.Player:UpdateTrauma('player', math.floor(BUI.Player.health.max*.25),	BUI.Player.health.max)
	--Show the UI layer
	SatuveUI:SetHidden(false)
end

function BUI.Menu.FramesRestore()
	BUI.inMenu=false
	--Unit Frames Display
	if BUI.init.Frames then
		if BUI.Vars.TargetFrame then
			BUI_TargetFrame:SetHidden(true)
		end
		if BUI.Vars.PlayerFrame then
			BUI_PlayerFrame:ClearAnchors()
			local anchor=BUI.Vars.FrameHorisontal and BUI.Vars.BUI_HPlayerFrame or BUI.Vars.BUI_PlayerFrame
			BUI_PlayerFrame:SetAnchor(anchor[1],SatuveUI,anchor[2],anchor[3],anchor[4])
		end
		if BUI.Vars.CurvedFrame~=0 then
			BUI.Curved.Initialize()
		end
		if BUI.Vars.BossFrame then
			if BUI.Frame["boss1"] then BUI.Frame["boss1"]:SetHidden(true) end
		end
	end
	BUI.Player:UpdateShield('player')
	BUI.Player:UpdateTrauma('player')
	--Toggle visibility
	SatuveUI:SetHidden(not BUI_SettingsWindow:IsHidden())
end

function BUI.Menu.Update(setting, value, reload)
	BUI.Vars[setting]=value
	if reload then SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI) end
end

function BUI.Menu.Reset(context)
	--Reset everything
	if not context then
		for var, value in pairs(BUI.Defaults) do BUI.Vars[var]=value end
		SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI)
	--Reset unit frames
	elseif context=="Frames" then
		for var, value in pairs(BUI.Frames.Defaults) do BUI.Vars[var]=value end
		BUI.Menu.UpdateFrames()
		BUI.Menu.UpdateOptions("BUI_MenuPlayerFrames")
		BUI.Menu.UpdateOptions("BUI_MenuTargetFrames")
		BUI.Menu.UpdateOptions("BUI_MenuGroupFrames")
	elseif context=="Positions" then
		if MoveMode_1 then
			local frames={
				"BUI_OnScreen","BUI_OnScreenS","BUI_PlayerFrame","BUI_HPlayerFrame","BUI_TargetFrame","BUI_BossFrame","BUI_RaidFrame",
				"BUI_Minimap","BUI_MiniMeter","BUI_GroupDPS","BUI_Attackers","BUI_Glyphs","BUI_BuffsUp",
				"BUI_BuffsP","BUI_BuffsPas","BUI_BuffsT","BUI_BuffsC","BUI_BuffsS",
				"BUI_Meter_Speed","BUI_Meter_Power","BUI_Meter_Crit","BUI_Meter_Exp","BUI_Meter_DPS","BUI_Meter_Criminal"
				}
			for _,frame in pairs(frames) do if BUI.Defaults[frame]~=nil then BUI.Vars[frame]=BUI.Defaults[frame] end end
		end
		if MoveMode_2 then
			for frame in pairs(BUI.DefaultFrames) do BUI.Vars[frame]=nil end
		end
		if MoveMode_1 or MoveMode_2 then
			SCENE_MANAGER:SetInUIMode(false) BUI.OnScreen.Notification(8,"Reloading UI") BUI.CallLater("ReloadUI",1000,ReloadUI)
		end
	elseif context=="Curved" then
		for var, value in pairs(BUI.Curved.Defaults) do BUI.Vars[var]=value end
		BUI.Curved.Initialize()
		BUI.Menu.UpdateOptions("BUI_MenuCurvedFrames")
	elseif context=="Stats" then
		for var, value in pairs(BUI.Stats.Defaults) do BUI.Vars[var]=value end
		BUI.Stats:Initialize()
		BUI.Menu.UpdateOptions("BUI_MenuDamageStatistics")
	elseif context=="Buffs" then
		for var, value in pairs(BUI.Buffs.Defaults) do BUI.Vars[var]=value end
		BUI.Buffs:Initialize()
		BUI.Menu.UpdateOptions("BUI_MenuBuffs")
	elseif context=="Actions" then
		for var, value in pairs(BUI.Actions.Defaults) do BUI.Vars[var]=value end
		BUI.Actions:Initialize()
		BUI.Menu.UpdateOptions("BUI_MenuActions")
	elseif context=="Colors" then
		for var, value in pairs(BUI.Colors.Defaults) do BUI.Vars[var]=value end
		BUI.Menu.UpdateFrames()
		BUI.Menu.UpdateOptions("BUI_MenuFrameColors")
	elseif context=="SameColors" then
		local vars={"FrameHealthColor","FrameMagickaColor","FrameStaminaColor","FrameShieldColor","FrameTraumaColor"}
		for _,var in pairs(vars) do BUI.Vars[var.."1"]=BUI.Vars[var] end
		BUI.Menu.UpdateFrames()
		BUI.Menu.UpdateOptions("BUI_MenuFrameColors")
	elseif context=="Minimap" then
		for var, value in pairs(BUI.MiniMap.Defaults) do BUI.Vars[var]=value end
		BUI.Menu.UpdateFrames()
		BUI.Menu.UpdateOptions("BUI_MenuMinimap")
	elseif context=="DefaultFrames" then
		local frames={"ZO_PlayerAttributeMagicka","ZO_PlayerAttributeStamina","ZO_PlayerAttributeSiegeHealth"}
		for frame in pairs(frames) do BUI.Vars[frame]=nil end
	end
end

function BUI.Menu.UpdateFrames(setting,value,...)
	--Maybe apply a new setting
	if (setting and value~=nil) then BUI.Vars[setting]=value end
	--Rebuild the frames dynamically
	BUI.Frames:Controls()
	--Reset the fade animation
	BUI.Frames.resetAnim=true
	--Re-populate the frames
	BUI.Frames.SetupPlayer()
	if BUI_RaidFrame then BUI.Frames:SetupGroup() end
	--Position the frame for menu display
	BUI.Menu.FramesReposition()
	if setting=="FramesTexture" then BUI.Frames.ChangeTextures() end
end

function BUI.Menu.MarkerLeader(force)
	if type(SetFloatingMarkerInfo)~="function" then return end

	-- Xbox client: first reset the floating marker before applying new data.
	-- Without this reset, size/texture changes can be ignored until reload.
	pcall(SetFloatingMarkerInfo, MAP_PIN_TYPE_GROUP_LEADER)

	if BUI.Vars.MarkerLeader then
		local size=tonumber(BUI.Vars.MarkerSize) or 24
		size=math.max(12,math.min(size,48))
		BUI.Vars.MarkerSize=size
		zo_callLater(function()
			pcall(SetFloatingMarkerInfo, MAP_PIN_TYPE_GROUP_LEADER, size, "/esoui/art/compass/groupleader.dds")
		end, 50)
	end
end

--Manage widgets
local function ShowWidgetButtons(self)
	BUI_Menu_Move_B1:ClearAnchors() BUI_Menu_Move_B1:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5,5+16) BUI_Menu_Move_B1:SetParent(self) BUI_Menu_Move_B1:SetHidden(false)
	BUI_Menu_Move_B2:ClearAnchors() BUI_Menu_Move_B2:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5,5) BUI_Menu_Move_B2:SetParent(self) BUI_Menu_Move_B2:SetHidden(false)
	BUI_Menu_Move_B3:ClearAnchors() BUI_Menu_Move_B3:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5-16,5) BUI_Menu_Move_B3:SetParent(self) BUI_Menu_Move_B3:SetHidden(false)
	BUI_Menu_Move_B4:ClearAnchors() BUI_Menu_Move_B4:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5-16,5+16) BUI_Menu_Move_B4:SetParent(self) BUI_Menu_Move_B4:SetHidden(false)
end

local function WidgetContext_UI(parent)	--Context menu
	local name=parent:GetName()
	local fs=17
	local w,h=260,fs*1.5*10+20+28
	local header=tonumber(parent.index) and "["..parent.index.."] "..parent.name:GetText() or parent.index
	local ui	=BUI.UI.TopLevelWindow("BUI_Menu_Context",	parent,	{w,h},	{TOP,BOTTOM,0,0}, false) ui:SetDrawTier(2)
	ui.bg		=BUI.UI.Backdrop(	"BUI_Menu_Context_Bg",		ui,		{w,h},		{TOPLEFT,TOPLEFT,0,0},	{0,0,0,.9}, {0.4,0.4,0.4,.9}, nil, false)
	BUI.UI.Label(	"BUI_Menu_Context_Id",	ui,	{w-20,fs*1.5},		{TOPLEFT,TOPLEFT,10,5},	BUI.UI.Font("esobold",fs,true), {.6,.6,.4,1}, {1,1}, header,	false)
	--Progress bar
	local label=BUI.UI.Label(	"BUI_Menu_Context_pBar_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,5+fs*1.5*1},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsProgress"))
	local enable=BUI.Vars[name] and BUI.Vars[name][8]
	BUI.UI.CheckBox("BUI_Menu_Context_pBar", label, {20,20}, {RIGHT,RIGHT,0,0}, enable,
		function(value)
			if not BUI.Vars[name] then BUI.Vars[name]={[8]=value} else BUI.Vars[name][8]=value end
			BUI.Frames.Widgets_Init(name)
			local ability=_G[name] if ability then ability:SetHandler("OnMouseEnter", ShowWidgetButtons) end
		end)
	--Progress bar side
	local label=BUI.UI.Label(	"BUI_Menu_Context_Side_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,5+fs*1.5*2},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsPSide"))
	local side=BUI.Vars[name] and BUI.Vars[name][6]
	BUI.UI.SimpleButton("BUI_Menu_Context_Side", label, {20,20}, {RIGHT,RIGHT,0,0}, (side and "/esoui/art/buttons/leftarrow_disabled.dds" or "/esoui/art/buttons/rightarrow_disabled.dds"), false,
		function(self)
			local side=BUI.Vars[name] and BUI.Vars[name][6]
			side=not side
			if not BUI.Vars[name] then BUI.Vars[name]={[6]=side} else BUI.Vars[name][6]=side end
			self:SetTexture(side and "/esoui/art/buttons/leftarrow_disabled.dds" or "/esoui/art/buttons/rightarrow_disabled.dds")
			BUI.Frames.Widgets_Init(name)
			local ability=_G[name] if ability then ability:SetHandler("OnMouseEnter", ShowWidgetButtons) end
		end)
	--Multi target
	local label=BUI.UI.Label(	"BUI_Menu_Context_mTarg_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,5+fs*1.5*3},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsMultiTarget"))
	local enable=BUI.Vars[name] and BUI.Vars[name][9]
	BUI.UI.CheckBox("BUI_Menu_Context_mTarg", label, {20,20}, {RIGHT,RIGHT,0,0}, enable,
		function(value)
			if not BUI.Vars[name] then BUI.Vars[name]={[9]=value} else BUI.Vars[name][9]=value end
		end)
	--Player effects
	local label=BUI.UI.Label(	"BUI_Menu_Context_Self_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,5+fs*1.5*4},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsSelfEffects"))
	local enable=not (BUI.Vars[name] and BUI.Vars[name][10])
	BUI.UI.CheckBox("BUI_Menu_Context_Self", label, {20,20}, {RIGHT,RIGHT,0,0}, enable,
		function(value)
			if not BUI.Vars[name] then BUI.Vars[name]={[10]=not value} else BUI.Vars[name][10]=not value end
		end)
	--Always show
	local label=BUI.UI.Label(	"BUI_Menu_Context_AllwaysShow_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,5+fs*1.5*5},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsAlwaysShow"))
	local enable=(BUI.Vars[name] and BUI.Vars[name][12])
	BUI.UI.CheckBox("BUI_Menu_Context_AllwaysShow", label, {20,20}, {RIGHT,RIGHT,0,0}, enable,
		function(value)
			if not BUI.Vars[name] then BUI.Vars[name]={[12]=value} else BUI.Vars[name][12]=value end
		end)
	--Ability cooldown
	local label=BUI.UI.Label(	"BUI_Menu_Context_Cooldown_Label",	ui,	{w-10-fs*4,fs*1.5},	{TOPLEFT,TOPLEFT,10,10+fs*1.5*6},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, GetString(SI_GAMEPAD_TOOLTIP_COOLDOWN_HEADER))
	label:SetMouseEnabled(true)
	label:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, BOTTOM, BUI.Loc("WidgetsCooldownDesc")) end)
	label:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
	BUI.UI.TextBox("BUI_Menu_Context_Cooldown",	ui,	{fs*4,fs*1.2},	{TOPLEFT,TOPLEFT,w-10-fs*4,10+fs*1.5*6},	5,	(BUI.Vars[name] and BUI.Vars[name][7] or parent.duration) or "",
		function(value)
			value=tonumber(value)
			if value and value>1000 then
				if not BUI.Vars[name] then BUI.Vars[name]={[7]=value} else BUI.Vars[name][7]=value end
			else
				if BUI.Vars[name] then BUI.Vars[name][7]=nil end
				BUI_Menu_Context_Cooldown.eb:SetText(parent.duration or "")
			end
		end)
	--Combine
	local label=BUI.UI.Label(	"BUI_Menu_Context_Combine_Label",	ui,	{w-10-fs*4,fs*1.5},	{TOPLEFT,TOPLEFT,10,10+fs*1.5*7},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsCombine"))
	label:SetMouseEnabled(true)
	label:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, BOTTOM, BUI.Loc("WidgetsCombineDesc")) end)
	label:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
	BUI.UI.TextBox("BUI_Menu_Context_Combine",	ui,	{fs*4,fs*1.2},	{TOPLEFT,TOPLEFT,w-10-fs*4,10+fs*1.5*7},	20,	tostring(BUI.Vars[name] and BUI.Vars[name][11] or ""),
		function(value)
			local id=tonumber(value)
			local WidgetId=(id and id>100 and id<900000) and id or string.len(value)>3 and value or nil
--			d(WidgetId)
			if WidgetId then
				BUI.Vars.Widgets[WidgetId]=true
				if not BUI.Vars[name] then BUI.Vars[name]={[11]=WidgetId} else BUI.Vars[name][11]=WidgetId end
				local refer_name="BUI_Widget_"..string.gsub(WidgetId," ","_")
				if not BUI.Vars[refer_name] then BUI.Vars[refer_name]={[11]=true} else BUI.Vars[refer_name][11]=true end
			else
				bui_a("Additional effect was removed",SOUNDS.NEGATIVE_CLICK)
				if BUI.Vars[name] then BUI.Vars[name][11]=nil end
				BUI_Menu_Context_Combine.eb:SetText("")
			end
		end)
	--Sound
	local label=BUI.UI.Label(	"BUI_Menu_Context_Sound_Label",	ui,	{w-10-fs*4,fs*1.5},	{TOPLEFT,TOPLEFT,10,10+fs*1.5*8},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, GetString(SI_AUDIO_OPTIONS_SOUND_ENABLED))
--	label:SetMouseEnabled(true)
--	label:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, BOTTOM, BUI.Loc("WidgetsSoundDesc")) end)
--	label:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
	local array={"Activation","Deactivation","Both","Disabled"}
	BUI.UI.ComboBox("BUI_Menu_Context_Sound",	ui,	{fs*7+2,fs*1.5},	{TOPLEFT,TOPLEFT,w-10-fs*7,10+fs*1.5*8}, array, (BUI.Vars[name] and BUI.Vars[name][13] or 4),
		function(i)
			if not BUI.Vars[name] then BUI.Vars[name]={[13]=i} else BUI.Vars[name][13]=i end
		end)
	--Delete
	local label=BUI.UI.Label(	"BUI_Menu_Context_Delete_Label",	ui,	{w-15,fs*1.5},		{TOPLEFT,TOPLEFT,10,10+fs*1.5*9},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, GetString(SI_MAIL_READ_DELETE))
	BUI.UI.SimpleButton("BUI_Menu_Context_Delete", label, {20,20}, {RIGHT,RIGHT,0,0}, 4, false, function()BUI.Buffs.RemoveFrom(BUI.Vars.Widgets,parent.index,"Widgets")end)
	--Close button
	local button=BUI_Menu_Context_Close or WINDOW_MANAGER:CreateControlFromVirtual("BUI_Menu_Context_Close", ui, "ZO_DefaultButton")
	button:SetWidth(90, 28)
	button:SetText(GetString(SI_DIALOG_CLOSE))
	button:SetAnchor(BOTTOM,ui,BOTTOM,0,-10)
	button:SetClickSound("Click")
	button:SetFont(BUI.UI.Font("standard",20,true))
	button:SetHandler("OnClicked", function()BUI_Menu_Context:SetHidden(true)end)
end

local function ManageWidgets_UI()		--Manage widgets
	local fs=17
	local rs=fs*1.8
	local w,h=280,rs*8+20+28
	local choices,values=BUI.Menu.MakeList(BUI.Vars.Widgets)
	BUI.ActionsUpdate()
	local a_choices,a_values=BUI.Menu.MakeList(BUI.Actions.AbilityBar)
	local b_choices,b_values=BUI.Menu.MakeBuffsList()
	local ResetFunc	=function(i,value)
		local value=values[i]
		if BUI.Vars.Widgets[value] then
			local id="BUI_Widget_"..string.gsub(value," ","_")
			local frame=_G[id]
			if BUI.Vars[id] then
				BUI.Vars[id][1]=CENTER
				BUI.Vars[id][2]=CENTER
				BUI.Vars[id][3]=0
				BUI.Vars[id][4]=0
			else
				BUI.Vars[id]={CENTER,CENTER,0,0}
			end
			if frame then
				frame:ClearAnchors()
				frame:SetAnchor(CENTER,SatuveUI,CENTER,0,0)
			end
		else
			bui_a("Widget \""..tostring(value).."\" is not found")
		end
	end
	local AddWidget=function(value)
		BUI.Buffs.AddTo(BUI.Vars.Widgets,value,"Widgets")
		local frame=_G["BUI_Widget_"..string.gsub(value," ","_")]
		if frame then
			frame:SetHidden(false)
			frame:SetHandler("OnMouseEnter", function(self) ShowWidgetButtons(self) end)
			frame:SetMovable(true)
		end
		choices,values=BUI.Menu.MakeList(BUI.Vars.Widgets)
		BUI_Menu_WManage_Reset_DropBox:UpdateValues(choices)
		BUI_Menu_WManage_Delete_DropBox:UpdateValues(choices)
	end

	local function AddTooltip(parent,text)	--Help
		if parent.help then return end
		parent.help=WINDOW_MANAGER:CreateControl("$(parent)Help", parent, CT_TEXTURE)
		parent.help:SetDimensions(26,26)
		parent.help:SetAnchor(RIGHT,parent,RIGHT,0,0)
		parent.help:SetTexture('/esoui/art/help/help_tabicon_tutorial_up.dds')
		parent.help:SetMouseEnabled(true)
		parent.help:SetHandler("OnMouseEnter", function(self)ZO_Tooltips_ShowTextTooltip(self,BOTTOM,text)end)
		parent.help:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
	end
	local ui	=BUI.UI.TopLevelWindow("BUI_Menu_WManage",	SatuveUI,	{w,h},	{RIGHT,RIGHT,-20,0}) ui:SetDrawTier(1)
	ui:SetMouseEnabled(true) ui:SetMovable(true)
	ui.bg		=BUI.UI.Backdrop(	"BUI_Menu_WManage_Bg",		ui,		{w,h},		{TOPLEFT,TOPLEFT,0,0},	{0,0,0,.9}, {0.4,0.4,0.4,.9})
	BUI.UI.Label(	"BUI_Menu_WManage_Id",	ui,	{w-20,rs},		{TOPLEFT,TOPLEFT,10,5},	BUI.UI.Font("esobold",fs,true), {.6,.6,.4,1}, {1,1}, BUI.Loc("WidgetsManage"))
	BUI.UI.Label(	"BUI_Menu_WManage_Add_Label",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*1},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsAdd"))
	--Add ability widget
	local label=BUI.UI.Label(	"BUI_Menu_WManage_Add_Ability",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*2},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsAbility"))
	local box=BUI.UI.ComboBox(	"BUI_Menu_WManage_Add_Ability_DropBox", label, {w*.5-10,28}, {TOPLEFT,TOPRIGHT,0,0}, a_choices, nil, function(i,value)AddWidget(a_values[i])end)
	box:SetDisabled(not BUI.Vars.Actions)
	if not BUI.Vars.Actions then AddTooltip(label,BUI.Loc("WidgetsAbilityDesc")) elseif label.help then label.help:SetHidden(true) end
	--Add buff widget
	local label=BUI.UI.Label(	"BUI_Menu_WManage_Add_Buff",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*3},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsBuff"))
	local box=BUI.UI.ComboBox(	"BUI_Menu_WManage_Add_Buff_DropBox", label, {w*.5-10,28}, {TOPLEFT,TOPRIGHT,0,0}, b_choices, nil, function(i,value)AddWidget(b_values[i])end)
	box:SetDisabled(not BUI.Vars.EnableStats or not BUI.Vars.StatsBuffs)
	if not BUI.Vars.EnableStats or not BUI.Vars.StatsBuffs then AddTooltip(label,BUI.Loc("WidgetsBuffDesc")) elseif label.help then label.help:SetHidden(true) end
	--Add custom widget
	local label=BUI.UI.Label(	"BUI_Menu_WManage_Add_Custom",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*4},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsCustom"))
	BUI.UI.TextBox(	"BUI_Menu_WManage_Add_Custom_TextBox",	ui,	{w*.5-10,fs*1.2},	{TOPLEFT,TOPLEFT,w*.5,10+rs*4},	20,	"", function(value)AddWidget(value)end)
	AddTooltip(label,BUI.Loc("WidgetsAddDesc"))
	--Reset position
	local label=BUI.UI.Label(	"BUI_Menu_WManage_Reset",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*6},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, BUI.Loc("WidgetsReset"))
	BUI.UI.ComboBox(	"BUI_Menu_WManage_Reset_DropBox", label, {w*.5-10,28}, {TOPLEFT,TOPRIGHT,0,0}, choices, nil, ResetFunc)
	--Delete widget
	local label=BUI.UI.Label(	"BUI_Menu_WManage_Delete",	ui,	{w*.5-10,rs},		{TOPLEFT,TOPLEFT,10,5+rs*7},	BUI.UI.Font("standard",fs,true), {.6,.6,.4,1}, {0,1}, GetString(SI_MAIL_READ_DELETE))
	BUI.UI.ComboBox(	"BUI_Menu_WManage_Delete_DropBox", label, {w*.5-10,28}, {TOPLEFT,TOPRIGHT,0,0}, choices, nil, function(i,value)BUI.Buffs.RemoveFrom(BUI.Vars.Widgets,values[i],"Widgets")end)
	--Close button
	local button=BUI_Menu_WManage_Close or WINDOW_MANAGER:CreateControlFromVirtual("BUI_Menu_WManage_Close", ui, "ZO_DefaultButton")
	button:SetWidth(90, 28)
	button:SetText(GetString(SI_DIALOG_CLOSE))
	button:SetAnchor(BOTTOM,ui,BOTTOM,0,-10)
	button:SetClickSound("Click")
	button:SetFont(BUI.UI.Font("standard",20,true))
	button:SetHandler("OnClicked", function()BUI.Menu.ManageWidgets(false)end)
end

local function MoveFramesButtons()
	--Add additional elements
	local ahchor=BUI.UI.Texture("BUI_Menu_Move_Anchor",	SatuveUI,	{26,26},	{TOP,TOP,0,5},	"/esoui/art/icons/mapkey/mapkey_dock.dds", false)
	move_anchor=SatuveUI
	if move_init then return end
	ahchor:SetDrawLayer(3)

	BUI.UI.SimpleButton("BUI_Menu_Move_B1", SatuveUI, {16,16}, {TOPRIGHT,TOPRIGHT,0,0}, "/esoui/art/miscellaneous/gamepad/arrow_down.dds", false,
		function(self)
			local frame=self:GetParent()
			local name=frame:GetName() if BUI.Vars.FrameHorisontal and name=="BUI_PlayerFrame" then name="BUI_HPlayerFrame" end
			BUI.Menu:SaveAnchor(frame,move_anchor)
			frame:ClearAnchors() frame:SetAnchor(BUI.Vars[name][1],SatuveUI,BUI.Vars[name][2],BUI.Vars[name][3],BUI.Vars[name][4])
		end,
		"Center frame by anchor")

	BUI.UI.SimpleButton("BUI_Menu_Move_B2", SatuveUI, {16,16}, {TOPRIGHT,TOPRIGHT,0,0}, "/esoui/art/icons/mapkey/mapkey_dock.dds", false,
		function(self)
			move_anchor=move_anchor==SatuveUI and self:GetParent() or SatuveUI
			ahchor:ClearAnchors() ahchor:SetAnchor(TOP,move_anchor,TOP,0,5) ahchor:SetHidden(false)
		end,
		"Set frame as anchor")

	BUI.UI.SimpleButton("BUI_Menu_Move_B3", SatuveUI, {16,16}, {TOPRIGHT,TOPRIGHT,0,0}, "/esoui/art/inventory/inventory_icon_hiddenby.dds", false,
		function(self)
			self:GetParent():SetHidden(true)
--			BUI_Menu_Move_B1:SetHidden(true) BUI_Menu_Move_B2:SetHidden(true) BUI_Menu_Move_B3:SetHidden(true) BUI_Menu_Move_B4:SetHidden(true)
		end,
		"Temporarily hide")

	BUI.UI.SimpleButton("BUI_Menu_Move_B4", SatuveUI, {16,16}, {TOPRIGHT,TOPRIGHT,0,0}, "/esoui/art/guild/gamepad/gp_guild_menuicon_customization.dds", false,
		function(self) WidgetContext_UI(self:GetParent()) end,
		"Settings")

	move_init=true
end

function BUI.Menu.ManageWidgets(move)
	if SCENE_MANAGER:IsInUIMode() and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(false) end
	--Move elements back to their normal positions
	if move then
		BUI.Menu.FramesRestore()
		ZO_WorldMap:SetHidden(true)
		_G["ZO_WorldMapMapFrame"]:SetHidden(true)
		SatuveUI.line_vert	=BUI.UI.Line("MyUI_Line_vert",	SatuveUI,	{0,SatuveUI:GetHeight()},	{TOPLEFT,TOP,0,0},	{.2,.8,.2,.5},1.8, false)
		SatuveUI.line_hor	=BUI.UI.Line("MyUI_Line_hor",	SatuveUI,	{SatuveUI:GetWidth(),0},	{TOPLEFT,LEFT,0,0},	{.2,.8,.2,.5},1.8, false)
		if BUI.Vars.CurvedFrame~=0 then
--			BUI.Curved.Initialize()
			BUI_Curved:SetAlpha(BUI.Vars.FrameOpacityIn/100)
			BUI_CurvedTarget:SetHidden(false)
			BUI_CurvedTarget:SetAlpha(BUI.Vars.FrameOpacityIn/100)
			BUI_Curved_Alt:SetHidden(false)
		end
		ManageWidgets_UI()
	else
		MyUI_Line_vert:SetHidden(true)
		MyUI_Line_hor:SetHidden(true)
		if BUI_Menu_Context then BUI_Menu_Context:SetHidden(true) end
		if BUI.Vars.CurvedFrame~=0 then
--			BUI.Curved.Initialize()
			BUI_Curved:SetAlpha(0) BUI_CurvedTarget:SetAlpha(0)
		end
		if BUI_Menu_WManage then BUI_Menu_WManage:SetHidden(true) end
	end

	--Unit Frames
	MoveFramesButtons()
	if BUI.Vars.EnableWidgets then
		for _id,enable in pairs(BUI.Vars.Widgets) do
			local id=string.gsub(_id," ","_")
			local ability=_G["BUI_Widget_"..id]
			if ability and enable then
				local data=BUI.Vars["BUI_Widget_"..id] if not data then data={} end
				ability:SetHidden(not (move or data[12]))
				ability:SetHandler("OnMouseEnter", move and function(self) ShowWidgetButtons(self) end or BUI.Buffs.ShowTooltip)
				ability:SetMovable(move)
				ability.timer:SetText("")
				ability.progress:SetHidden(not (move and data[8]))
				ability.bar:SetWidth(BUI.Vars.WidgetsPWidth-4)
			end
		end
	end
--	/script for id in pairs(BUI.Vars.Widgets) do _G["BUI_Widget_"..string.gsub(id," ","_")]:SetHidden(false) end
	SetGameCameraUIMode(move)
	BUI.move=move
	--Register events
	if move then
		local function OnLayerChange(eventCode, layerIndex, activeLayerIndex)
			if layerIndex<=4 and activeLayerIndex>2 then
				SatuveUI:SetHandler("OnEffectivelyShown", nil)
				BUI.Menu.ManageWidgets(false)
			end
		end
		--EVENT_MANAGER:RegisterForEvent("BUI_Event", EVENT_ACTION_LAYER_POPPED	,OnLayerChange)
		EVENT_MANAGER:RegisterForEvent("BUI_Event", EVENT_ACTION_LAYER_PUSHED	,OnLayerChange)
	else
		BUI_Menu_Move_Anchor:SetHidden(true) BUI_Menu_Move_B1:SetHidden(true) BUI_Menu_Move_B2:SetHidden(true) BUI_Menu_Move_B3:SetHidden(true) BUI_Menu_Move_B4:SetHidden(true)
		EVENT_MANAGER:UnregisterForEvent("BUI_Event", EVENT_ACTION_LAYER_POPPED)
		EVENT_MANAGER:UnregisterForEvent("BUI_Event", EVENT_ACTION_LAYER_PUSHED)
	end
end

--Move frames
-- Xbox adaptation: modal Move Frames mode.
local function SXUI_MoveModeOverlay(show)
	local overlay=_G["SXUI_MoveModeOverlay"]
	if not overlay then
		overlay=WINDOW_MANAGER:CreateTopLevelWindow("SXUI_MoveModeOverlay")
		overlay:SetDimensions(GuiRoot:GetDimensions())
		overlay:ClearAnchors()
		overlay:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
		overlay:SetDrawTier(DT_LOW)
		overlay:SetDrawLayer(DL_BACKGROUND)
		overlay:SetDrawLevel(0)
		overlay:SetMouseEnabled(false)
		if overlay.SetKeyboardEnabled then overlay:SetKeyboardEnabled(true) end
		local hint=BUI.UI.Backdrop("SXUI_MoveModeHint",overlay,{700,76},{TOP,TOP,0,28},{0,0,0,.86},{1,.82,.25,1},nil,false)
		hint:SetEdgeTexture("",8,2,2)
		BUI.UI.Label("SXUI_MoveModeHintText",hint,{680,66},{CENTER,CENTER,0,0},BUI.UI.Font("standard",20,true),{1,1,1,1},{1,1},"MOVE FRAMES MODE\nD-Pad = select frame  •  A = move  •  B or View = Exit and save",false)
		overlay:SetHandler("OnKeyDown",function(self,key)
			local editor=BUI.FrameEditor
			if editor and editor.HandleKeyDown and editor:HandleKeyDown(key) then return true end
			if key==KEY_ESCAPE or key==KEY_GAMEPAD_BACK or key==KEY_GAMEPAD_BACK_HOLD then
				if BUI.move then BUI.Menu.MoveFrames(false) end
				return true
			end
			-- A and B are owned by the editor keybind group. Do not consume their
			-- raw key events before ESO can invoke the matching callbacks.
			return false
		end)
	end
	overlay:SetHidden(not show)
	if show and overlay.TakeFocus then overlay:TakeFocus()
	elseif not show and overlay.LoseFocus then overlay:LoseFocus() end
end

local SXUI_MoveGroups={
	["BUI_PlayerFrame"]={"BUI_BuffsP","BUI_BuffsPas"},
	["BUI_TargetFrame"]={"BUI_BuffsT"},
}

local SXUI_MovableFrames={}
local function SXUI_ResetMovableFrames()
	for index=#SXUI_MovableFrames,1,-1 do SXUI_MovableFrames[index]=nil end
	BUI.SXUI_MovableFrames=SXUI_MovableFrames
end
local function SXUI_RegisterMovableFrame(control,saveName,anchorPoint,isDefault,onConfirm,onCancel)
	if not control then return end
	for _,entry in ipairs(SXUI_MovableFrames) do if entry.control==control then return end end
	table.insert(SXUI_MovableFrames,{control=control,saveName=saveName,anchorPoint=anchorPoint,isDefault=isDefault==true,onConfirm=onConfirm,onCancel=onCancel})
end

local function SXUI_GetMovableFrame(control)
	for _,entry in ipairs(SXUI_MovableFrames) do if entry.control==control then return entry end end
end

local function SXUI_PrepareFrameForDrag(frame)
	if not frame or not frame.GetCenter then return end
	local x,y=frame:GetCenter()
	local rootX,rootY=GuiRoot:GetCenter()
	if not x or not y or not rootX or not rootY then return end
	-- Preserve the exact current on-screen position before StartMoving().
	-- This prevents ESO from resolving old relative anchors to the screen centre
	-- when a frame begins to drag.
	frame:ClearAnchors()
	frame:SetAnchor(CENTER,GuiRoot,CENTER,x-rootX,y-rootY)
end

local function SXUI_StartLinkedMove(frame)
	local name=frame and frame.GetName and frame:GetName()
	local linked=name and SXUI_MoveGroups[name]
	if not linked then return end
	local fx,fy=frame:GetCenter()
	if not fx then return end
	frame.SXUI_LinkedMove={}
	for _,linkedName in ipairs(linked) do
		local ctrl=_G[linkedName]
		if ctrl and not ctrl:IsHidden() then
			local cx,cy=ctrl:GetCenter()
			if cx then table.insert(frame.SXUI_LinkedMove,{control=ctrl,dx=cx-fx,dy=cy-fy}) end
		end
	end
	if #frame.SXUI_LinkedMove>0 then
		EVENT_MANAGER:UnregisterForUpdate("SXUI_LinkedFrameMove")
		EVENT_MANAGER:RegisterForUpdate("SXUI_LinkedFrameMove",16,function()
			if not BUI.move or not frame.SXUI_LinkedMove then EVENT_MANAGER:UnregisterForUpdate("SXUI_LinkedFrameMove") return end
			local x,y=frame:GetCenter() if not x then return end
			local rootX,rootY=GuiRoot:GetCenter()
			for _,entry in ipairs(frame.SXUI_LinkedMove) do
				local ctrl=entry.control
				if ctrl then ctrl:ClearAnchors() ctrl:SetAnchor(CENTER,GuiRoot,CENTER,(x+entry.dx)-rootX,(y+entry.dy)-rootY) end
			end
		end)
	end
end

local function SXUI_StopLinkedMove(frame)
	EVENT_MANAGER:UnregisterForUpdate("SXUI_LinkedFrameMove")
	if not frame or not frame.SXUI_LinkedMove then return end
	for _,entry in ipairs(frame.SXUI_LinkedMove) do if entry.control then BUI.Menu:SaveAnchor(entry.control) end end
	frame.SXUI_LinkedMove=nil
end

-- BUI_RaidFrame alone uses one canonical persistent coordinate system:
-- its actual top-left corner relative to GuiRoot's top-left corner.
function BUI.Menu.SaveRaidFrameAnchor(control)
	if not control or not BUI.Vars or type(control.GetLeft)~="function" or type(control.GetTop)~="function" then return false end
	if not GuiRoot or type(GuiRoot.GetLeft)~="function" or type(GuiRoot.GetTop)~="function" then return false end
	local frameLeft,frameTop=control:GetLeft(),control:GetTop()
	local rootLeft,rootTop=GuiRoot:GetLeft(),GuiRoot:GetTop()
	if type(frameLeft)~="number" or type(frameTop)~="number" or type(rootLeft)~="number" or type(rootTop)~="number" then return false end
	local x,y=frameLeft-rootLeft,frameTop-rootTop
	BUI.Vars.BUI_RaidFrame={TOPLEFT,TOPLEFT,x,y}
	control:ClearAnchors()
	control:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
	return true
end

-- Xbox adaptation: reliable drag/save linkage for every movable BUI frame.
local function SXUI_SetFrameMoveLinked(frame, move, saveName, anchorPoint, onConfirm)
	if not frame then return end
	if frame.SetMouseEnabled then frame:SetMouseEnabled(move) end
	if frame.SetMovable then frame:SetMovable(move) end
	if move then
		if not frame.SXUI_MoveHandlersSaved and frame.GetHandler then
			frame.SXUI_OriginalMouseDown=frame:GetHandler("OnMouseDown")
			frame.SXUI_OriginalMouseUp=frame:GetHandler("OnMouseUp")
			frame.SXUI_OriginalMouseEnter=frame:GetHandler("OnMouseEnter")
			frame.SXUI_OriginalMouseExit=frame:GetHandler("OnMouseExit")
			frame.SXUI_MoveHandlersSaved=true
		end
		frame:SetHandler("OnMouseDown", function(self,button)
			if button==MOUSE_BUTTON_INDEX_LEFT and self.StartMoving then
				SXUI_StartLinkedMove(self)
				SXUI_PrepareFrameForDrag(self)
				self:StartMoving()
			end
		end)
		frame:SetHandler("OnMouseUp", function(self)
			if self.StopMovingOrResizing then self:StopMovingOrResizing() end
			if type(onConfirm)=="function" then onConfirm(self) else BUI.Menu:SaveAnchor(self,nil,saveName,anchorPoint) end
			SXUI_StopLinkedMove(self)
		end)
	else
		if frame.SXUI_MoveHandlersSaved then
			frame:SetHandler("OnMouseDown",frame.SXUI_OriginalMouseDown)
			frame:SetHandler("OnMouseUp",frame.SXUI_OriginalMouseUp)
			frame:SetHandler("OnMouseEnter",frame.SXUI_OriginalMouseEnter)
			frame:SetHandler("OnMouseExit",frame.SXUI_OriginalMouseExit)
		end
	end
end

local function MoveDefaultFrames(move)
	if BUI.init.DefaultFrames then
		BUI_Move:SetHidden(not move)
		if move then
			for name in pairs(BUI.DefaultFrames) do
				SXUI_RegisterMovableFrame(_G[name.."_BUI_BG"],name,nil,true)
			end
		end
	elseif move then
		BUI.UI.TopLevelWindow("BUI_Move",GuiRoot,{GuiRoot:GetWidth(),GuiRoot:GetHeight()},{CENTER,CENTER,0,0},false)
		for name,desc in pairs(BUI.DefaultFrames) do
			local frame=_G[name]
			local lX,lY,anchorPoint=0,0,CENTER
			if frame and not (name=="ZO_LootHistoryControl_Keyboard" and BUI.GamepadMode) and not (name=="ZO_LootHistoryControl_Gamepad" and not BUI.GamepadMode) then
			if name=="ZO_LootHistoryControl_Keyboard" then
				lX,lY=-300,-95
				anchorPoint=BOTTOMRIGHT
			elseif name=="ZO_LootHistoryControl_Gamepad" then
				lX,lY=260,-95
				anchorPoint=BOTTOMLEFT
			elseif name=="ZO_AlertTextNotification" then
				lX=ZO_Compass:GetRight()+40-GuiRoot:GetRight()
				lY=100
				anchorPoint=TOPRIGHT
			elseif name=="ZO_PlayerAttributeMagicka" then
				anchorPoint=RIGHT
			elseif name=="ZO_PlayerAttributeStamina" then
				anchorPoint=LEFT
			elseif name=="ZO_EndDunHUDTrackerContainer" then
				frame:SetWidth(200)
				lX,lY=-100,-20
				anchorPoint=BOTTOMRIGHT
			end
			local w,h=frame:GetDimensions()
			if w==0 then w=14 end w=w+math.abs(lX)
			if h==0 then h=14 end h=h+math.abs(lY)
			local bg=BUI.UI.Backdrop(name.."_BUI_BG",	frame,	{w,h},	{CENTER,CENTER,lX/2,lY/2},	{0,.1,.4,0.3}, {0,0,0,1}, nil, false)
			bg:SetParent(BUI_Move)
			SXUI_RegisterMovableFrame(bg,name,anchorPoint,true)
			BUI.UI.Label(name.."_BUI_Label",	bg,	{string.len(desc)*14,14},	{CENTER,CENTER,0,0},	BUI.UI.Font("trajan",14,true), nil, {1,1}, desc, false)
			BUI.UI.Line(name.."_Line_hor",	bg,	{w+200,0},	{TOPLEFT,LEFT,-100,0},	{.8,.8,.8,.4},1.8, false)
			BUI.UI.Line(name.."_Line_vert",	bg,	{0,h+200},	{TOPLEFT,TOP,0,-100},	{.8,.8,.8,.4},1.8, false)
			bg:SetMovable(true)
			bg:SetMouseEnabled(true)
			bg:SetHandler("OnMouseDown", function(self,button)
				if button==MOUSE_BUTTON_INDEX_LEFT and self.StartMoving then
					SXUI_PrepareFrameForDrag(self)
					self:StartMoving()
				end
			end)
			bg:SetHandler("OnMouseUp", function(self)
				if self.StopMovingOrResizing then self:StopMovingOrResizing() end
				BUI.Menu:SaveAnchor(self,nil,name,anchorPoint)
				BUI.Frames.ZO_Frame_reposition()
				end)
			end
		end
		BUI.init.DefaultFrames=true
	end
	BUI.moveDefault=move
end

function BUI.Menu.MoveFrames(move)
	if not (MoveMode_1 or MoveMode_2) then return end
	if move then SXUI_ResetMovableFrames() end
	if move and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(true) end
	SXUI_MoveModeOverlay(move)
	--Move elements back to their normal positions
	if move then
		BUI.inMenu=false
		-- Hide the settings window while editing frames so it cannot block drag targets.
		if BUI_SettingsWindow then BUI_SettingsWindow:SetHidden(true) end
		BUI.Menu.FramesRestore()
		ZO_WorldMap:SetHidden(true)
		_G["ZO_WorldMapMapFrame"]:SetHidden(true)
		SatuveUI.line_vert	=BUI.UI.Line("MyUI_Line_vert",	SatuveUI,	{0,SatuveUI:GetHeight()},	{TOPLEFT,TOP,0,0},	{.2,.8,.2,.5},1.8, false)
		SatuveUI.line_hor	=BUI.UI.Line("MyUI_Line_hor",	SatuveUI,	{SatuveUI:GetWidth(),0},	{TOPLEFT,LEFT,0,0},	{.2,.8,.2,.5},1.8, false)
	else
		MyUI_Line_vert:SetHidden(true)
		MyUI_Line_hor:SetHidden(true)
	end

	local function ShowButtons(self)
		BUI_Menu_Move_B1:ClearAnchors() BUI_Menu_Move_B1:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5,5+16) BUI_Menu_Move_B1:SetParent(self) BUI_Menu_Move_B1:SetHidden(false)
		BUI_Menu_Move_B2:ClearAnchors() BUI_Menu_Move_B2:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5,5) BUI_Menu_Move_B2:SetParent(self) BUI_Menu_Move_B2:SetHidden(false)
		BUI_Menu_Move_B3:ClearAnchors() BUI_Menu_Move_B3:SetAnchor(TOPRIGHT,self,TOPRIGHT,-5-16,5) BUI_Menu_Move_B3:SetParent(self) BUI_Menu_Move_B3:SetHidden(false)
		BUI_Menu_Move_B4:SetHidden(true)
	end
	--Unit Frames
	MoveFramesButtons()
	if BUI.init.Frames and MoveMode_1 then
		local frames={}
		local function AddFrame(frame,saveName,anchorPoint,isDefault,onConfirm,onCancel)
			if frame then table.insert(frames,frame) SXUI_RegisterMovableFrame(frame,saveName,anchorPoint,isDefault,onConfirm,onCancel) end
		end
		if BUI.Vars.RaidFrames then AddFrame(BUI_RaidFrame,nil,nil,false,BUI.Menu.SaveRaidFrameAnchor) end
		if BUI.Vars.PlayerFrame then AddFrame(BUI_PlayerFrame) end
		if BUI.Vars.TargetFrame then AddFrame(BUI_TargetFrame) end
		if BUI.Vars.PlayerBuffs then AddFrame(BUI_BuffsP) end
		if BUI.Vars.EnableCustomBuffs then AddFrame(BUI_BuffsC) end
		if BUI.Vars.EnableSynergyCd then AddFrame(BUI_BuffsS) end
		if BUI.Vars.TargetBuffs then AddFrame(BUI_BuffsT) end
		if BUI.Vars.BuffsPassives=="On additional panel" then AddFrame(BUI_BuffsPas) end
		if BUI.Vars.BossFrame then AddFrame(BUI_BossFrame) end
		if move and BUI.Vars.MiniMap and BUI.MiniMap and type(BUI.MiniMap.PrepareMoveHandle)=="function" then
			local handle=BUI.MiniMap.PrepareMoveHandle()
			if handle then AddFrame(handle,"Minimap",nil,false,BUI.MiniMap.CommitMoveHandle,BUI.MiniMap.CancelMoveHandle) end
		end
		if BUI.Vars.NotificationsTrial or BUI.Vars.NotificationsWorld or BUI.Vars.NotificationsGroup then AddFrame(BUI_OnScreen) AddFrame(BUI_OnScreenS) end
		if BUI.Vars.Glyphs then AddFrame(BUI_Glyphs) end
		if BUI.Vars.StatsMiniMeter then AddFrame(BUI_MiniMeter) end
		if BUI.Vars.StatsGroupDPSframe then AddFrame(BUI_GroupDPS) end
		if BUI.Vars.Attackers then AddFrame(BUI_Attackers) end
		if BUI_BuffsUp and BUI.Vars.BUI_BuffsUp then AddFrame(BUI_BuffsUp) end
		for _,name in pairs(BUI.Meters.List) do
			if BUI.Vars["Meter_"..name] then AddFrame(_G["BUI_Meter_"..name]) end
		end
		for _, frame in pairs(frames) do
			local entry=SXUI_GetMovableFrame(frame)
			SXUI_SetFrameMoveLinked(frame,move,entry and entry.saveName,entry and entry.anchorPoint,entry and entry.onConfirm)
			frame:SetMouseEnabled(move)
			frame:SetHidden(false)
			frame:SetAlpha(1)
			if move then frame:SetHandler("OnMouseEnter", ShowButtons) end
			if frame.backdrop then frame.backdrop:SetHidden(not move) end
			if frame.base then frame.base:SetHidden(false) end
			if move then
				local name=frame:GetName()
				local width=frame:GetWidth()
				local height=frame:GetHeight()
				frame.line_top	=BUI.UI.Line(name.."_Line_top",	frame,	{width+600,0},	{TOPLEFT,TOPLEFT,-300,0},	{.8,.8,.8,.3},1.8, false)
				frame.line_bot	=BUI.UI.Line(name.."_Line_bot",	frame,	{width+600,0},	{TOPLEFT,BOTTOMLEFT,-300,0},	{.8,.8,.8,.3},1.8, false)
				frame.line_left	=BUI.UI.Line(name.."_Line_left",	frame,	{0,height+600},	{TOPLEFT,TOPLEFT,0,-300},	{.8,.8,.8,.3},1.8, false)
				frame.line_right	=BUI.UI.Line(name.."_Line_right",	frame,	{0,height+600},	{TOPLEFT,TOPRIGHT,0,-300},	{.8,.8,.8,.3},1.8, false)
				frame.line_hor	=BUI.UI.Line(name.."_Line_hor",	frame,	{width+200,0},	{TOPLEFT,LEFT,-100,0},		{.8,.8,.8,.3},1.8, false)
				frame.line_vert	=BUI.UI.Line(name.."_Line_vert",	frame,	{0,height+200},	{TOPLEFT,TOP,0,-100},		{.8,.8,.8,.3},1.8, false)
			else
				if frame.line_top then frame.line_top:SetHidden(true) end
				if frame.line_bot then frame.line_bot:SetHidden(true) end
				if frame.line_left then frame.line_left:SetHidden(true) end
				if frame.line_right then frame.line_right:SetHidden(true) end
				if frame.line_hor then frame.line_hor:SetHidden(true) end
				if frame.line_vert then frame.line_vert:SetHidden(true) end
			end
		end
		--If we are done moving, make sure frame visibility is correct
		if not move then
			if BUI.MiniMap and type(BUI.MiniMap.HideMoveHandle)=="function" then BUI.MiniMap.HideMoveHandle() end
			BUI.Frames:SetupPlayer()
			if BUI_TargetFrame then BUI_TargetFrame:SetHidden(true) end
			BUI.Frames:SetupGroup()
			if BUI.Vars.MiniMap then BUI.MiniMap.Show() end
		end
	end
	if MoveMode_2 then MoveDefaultFrames(move) end
	SetGameCameraUIMode(move)
	BUI.move=move
	if not move and SCENE_MANAGER:IsInUIMode() and not WINDOW_MANAGER:IsSecureRenderModeEnabled() then SCENE_MANAGER:SetInUIMode(false) end
	--Register events
	if move then
		local function OnLayerChange(eventCode, layerIndex, activeLayerIndex)
		--	d(BUI.TimeStamp().." ["..eventCode.."] "..layerIndex.." "..activeLayerIndex)
			--We only need to act if it's in move mode
			if not BUI.move and not BUI.moveDefault then return end
			if layerIndex<=4 and activeLayerIndex>2 then
			--Unregister events
				EVENT_MANAGER:UnregisterForEvent("BUI_Event", EVENT_ACTION_LAYER_POPPED)
				EVENT_MANAGER:UnregisterForEvent("BUI_Event", EVENT_ACTION_LAYER_PUSHED)
				SatuveUI:SetHandler("OnEffectivelyShown", nil)
				if BUI.move then BUI.Menu.MoveFrames(false) end
		--		if BUI.moveDefault then BUI.Menu:MoveDefaultFrames(false) end
			end
		end
		--EVENT_MANAGER:RegisterForEvent("BUI_Event", EVENT_ACTION_LAYER_POPPED	,OnLayerChange)
		EVENT_MANAGER:RegisterForEvent("BUI_Event", EVENT_ACTION_LAYER_PUSHED	,OnLayerChange)
	else
		BUI_Menu_Move_Anchor:SetHidden(true) BUI_Menu_Move_B1:SetHidden(true) BUI_Menu_Move_B2:SetHidden(true) BUI_Menu_Move_B3:SetHidden(true) BUI_Menu_Move_B4:SetHidden(true)
	end
end

function BUI.Menu:SaveAnchor(control,anchor,name,anchorPoint,widget_side,widget_cd,widget_progress,multi_target,self_effects,combine,allwaysshow,sound)
	--Get anchor position
	local anchorX=0
	local w,h=control:GetWidth(),control:GetHeight()
	anchorPoint=anchorPoint or CENTER
	if anchor and anchor~=SatuveUI then
		local _, point, _, _, offsetX, offsetY=anchor:GetAnchor()
		offsetX=point==128 and offsetX or((point==3 or point==6) and offsetX-GuiRoot:GetWidth()/2+w/2 or GuiRoot:GetWidth()/2+offsetX-w/2)
--		offsetY=point==128 and offsetY or((point==3 or point==9) and offsetY-GuiRoot:GetHeight()/2+h/2 or GuiRoot:GetHeight()/2+offsetY-h/2)
		anchorX=math.floor(offsetX*10)/10 --offsetY=math.floor(offsetY*10)/10
	end
	--Get the new position
	local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY=control:GetAnchor()
	if not isValidAnchor then return end
	--Save the anchors
	offsetX=math.floor(offsetX*10)/10 offsetY=math.floor(offsetY*10)/10
	frame=control:GetName() if BUI.Vars.FrameHorisontal and frame=="BUI_PlayerFrame" then frame="BUI_HPlayerFrame" end
	name=name or frame
	if frame=="BUI_RaidFrame" then
		BUI.Menu.SaveRaidFrameAnchor(control)
	else
--		local anchor_name={[BOTTOM]="BOTTOM",[BOTTOMLEFT]="BOTTOMLEFT",[BOTTOMRIGHT]="BOTTOMRIGHT",[CENTER]="CENTER",[LEFT]="LEFT",[NONE]="NONE",[RIGHT]="RIGHT",[TOP]="TOP",[TOPLEFT]="TOPLEFT",[TOPRIGHT]="TOPRIGHT"}
--		d(frame..": "..anchor_name[point]..", "..anchor_name[relativePoint]..", "..offsetX.. ", "..offsetY)
		offsetX=point==128 and offsetX or((point==3 or point==6) and offsetX-GuiRoot:GetWidth()/2+w/2 or GuiRoot:GetWidth()/2+offsetX-w/2)
		offsetY=point==128 and offsetY or((point==3 or point==9) and offsetY-GuiRoot:GetHeight()/2+h/2 or GuiRoot:GetHeight()/2+offsetY-h/2)
		offsetX=math.floor(offsetX*10)/10 offsetY=math.floor(offsetY*10)/10
		if anchorPoint==RIGHT or anchorPoint==BOTTOMRIGHT or anchorPoint==TOPRIGHT then offsetX=offsetX+w/2
		elseif anchorPoint==LEFT or anchorPoint==BOTTOMLEFT or anchorPoint==TOPLEFT then offsetX=offsetX-w/2
		end
		if anchorPoint==BOTTOM or anchorPoint==BOTTOMRIGHT or anchorPoint==BOTTOMRIGHT then offsetY=offsetY+h/2
		elseif anchorPoint==TOP or anchorPoint==TOPRIGHT or anchorPoint==TOPLEFT then offsetY=offsetY-h/2
		end
		BUI.Vars[name]={[1]=anchorPoint,[2]=CENTER,[3]=(anchor and anchorX or offsetX),[4]=offsetY,[6]=widget_side,[7]=widget_cd,[8]=widget_progress,[9]=multi_target,[10]=self_effects,[11]=combine,[12]=allwaysshow,[13]=sound}
--		d("New: "..anchor_name[anchorPoint]..", "..anchor_name[CENTER]..", "..(anchor and anchorX or offsetX)..", "..offsetY)
	end
end
