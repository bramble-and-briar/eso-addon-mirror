VEQ = VEQ or {}
-- defaults Vars

function VEQ.CreateSettings()
    --figure out 
    --Load LibAddonMenu
    local LAM = LibAddonMenu2 
    --Load LibMediaProvider
    local LMP = LibMediaProvider 
	
	local VEQAuthor = "|c3CB371@Masteroshi430|r"
	local VEQVersion = "2026.09.28"
	local fontList = LMP:List('font')
	local fontStyles = {"normal", "outline", "shadow", "soft-shadow-thick", "soft-shadow-thin", "thick-outline"}
	local iconList = {"Arrow ESO (Default)", "Icon Dragonknight", "Icon Nightblade", "Icon Sorcerer", "Icon Templar"}
	-- This one has quest to chat maybe 1.6 version
	--local actionList = {"None", "Change Assisted Quest", "Filter by Current Zone", "Share a Quest", "Show on Map", "Remove a Quest", "Quest Info to Chat", "Quest Options Menu"}
	local actionList = {"None", "Share Quest", "Show Quest on Map", "Beam me There", "Abandon Quest", "Quest Options Menu"}
	--local sortList = {"Zone+Name", "Focused+Zone+Name"}
	--local sortlist = {VEQ.mylanguage.sort_zone_name, VEQ.mylanguage.sort_focus_zone_name}
	local DirectionList = {"TOP", "BOTTOM"}
	local HideObjOptionList = {"Disabled","Focused Quest","Focused Zone"}
	local ChatSetupList = {"Disabled","Tracker Messages Only","Quest Details Only","All Chat Messages"}

	local optionsData = {}
	

	

    -- Create new menu
	local panelData = {
		type = "panel",
		name = VEQ.mylanguage.lang_veq_settings,
		displayName = ZO_HIGHLIGHT_TEXT:Colorize(VEQ.mylanguage.lang_veq_settings),	author = VEQAuthor,
		version = VEQVersion,
		slashCommand = "/veq",
		registerForRefresh = true,
		--registerFordefaults = true,
		}
	LAM:RegisterAddonPanel("VEQ_Settings", panelData)
	-- **setup info**
	--Global Settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_global_settings,
		controls = {
			{--Hide When in Combat
				type = "checkbox",
				name = VEQ.mylanguage.lang_HideInCombat,
				tooltip = VEQ.mylanguage.lang_HideInCombat_tip,
				getFunc = VEQ.GetHideInCombatOption,
				setFunc = VEQ.SetHideInCombatOption,
			},
			{--Overall Width
				type = "slider",
				name = VEQ.mylanguage.lang_overall_width,
				tooltip = VEQ.mylanguage.lang_overall_width_tip,
				min = 100,
				max = 600,
				getFunc = VEQ.GetBgWidth,
				setFunc = VEQ.SetBgWidth,
			},
			-- {--Lock BackGround Position
				-- type = "checkbox",
				-- name = VEQ.mylanguage.lang_position_lock,
				-- tooltip = VEQ.mylanguage.lang_position_lock_tip,
				-- getFunc = VEQ.GetPositionLockOption,
				-- setFunc = VEQ.SetPositionLockOption,
			-- },
			{--intelligent Background
				type = "checkbox",
				name = VEQ.mylanguage.lang_intelligent_background,
				tooltip = VEQ.mylanguage.lang_intelligent_background_tip,
				getFunc = VEQ.GetIntelligentBackgroundOption,
				setFunc = VEQ.SetIntelligentBackgroundOption,
			},
		},
	} -- Mouse
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_mouse_settings,
		controls = {
			{--Mouse Left Button
				type = "dropdown",
				name = VEQ.mylanguage.lang_mouse_1,
				tooltip = VEQ.mylanguage.lang_mouse_1_tip,
				choices = actionList,
				getFunc = VEQ.GetButton1,
				setFunc = VEQ.SetButton1,
			},
			{--Mouse Cnter Button
				type = "dropdown",
				name = VEQ.mylanguage.lang_mouse_2,
				tooltip = VEQ.mylanguage.lang_mouse_2_tip,
				choices = actionList,
				getFunc = VEQ.GetButton3,
				setFunc = VEQ.SetButton3,
			},
			{--Mouse Right Button
				type = "dropdown",
				name = VEQ.mylanguage.lang_mouse_3,
				tooltip = VEQ.mylanguage.lang_mouse_3_tip,
				choices = actionList,
				getFunc = VEQ.GetButton2,
				setFunc = VEQ.SetButton2,
			},
			{--Mouse Button 4
				type = "dropdown",
				name = VEQ.mylanguage.lang_mouse_4,
				tooltip = VEQ.mylanguage.lang_mouse_4_tip,
				choices = actionList,
				getFunc = VEQ.GetButton4,
				setFunc = VEQ.SetButton4,
			},
			{--Mouse Button 5
				type = "dropdown",
				name = VEQ.mylanguage.lang_mouse_5,
				tooltip = VEQ.mylanguage.lang_mouse_5_tip,
				choices = actionList,
				getFunc = VEQ.GetButton5,
				setFunc = VEQ.SetButton5,
			},
		},
	--[[}-- Chat Setup
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_chat_settings,
		controls = {
			{--Enbaled Addon Messaging
				type = "checkbox",
				name = VEQ.mylanguage.lang_Chat_AddonMessages,
				tooltip = VEQ.mylanguage.lang_Chat_AddonMessages_tip,
				getFunc = VEQ.GetChat_AddonMessages,
				setFunc = VEQ.SetChat_AddonMessages,
			},
			{--Chat Addon Message Header Color
				type = "colorpicker",
				name = VEQ.mylanguage.lang_Chat_AddonMessage_HeaderColor,
				tooltip = VEQ.mylanguage.lang_Chat_AddonMessage_HeaderColor_tip,
				getFunc = VEQ.GetChat_AddonMessage_HeaderColor,
				setFunc = VEQ.SetChat_AddonMessage_HeaderColor,
				disabled = function() return not VEQ.SavedVars.Chat_AddonMessages end,
			},
			{--Chat Addon Message Header Color
				type = "colorpicker",
				name = VEQ.mylanguage.lang_Chat_AddonMessage_MsgColor,
				tooltip = VEQ.mylanguage.lang_Chat_AddonMessage_MsgColor_tip,
				getFunc = VEQ.GetChat_AddonMessage_MsgColor,
				setFunc = VEQ.SetChat_AddonMessage_MsgColor,
				disabled = function() return not VEQ.SavedVars.Chat_AddonMessages end,
			},
			{--Enable Quest Info
				type = "checkbox",
				name = VEQ.mylanguage.lang_Chat_QuestInfo,
				tooltip = VEQ.mylanguage.lang_Chat_Chat_QuestInfo,
				getFunc = VEQ.GetChat_QuestInfo,
				setFunc = VEQ.SetChat_QuestInfo,
			},
			{--Chat Addon Message Header Color
				type = "colorpicker",
				name = VEQ.mylanguage.lang_Chat_QuestInfo_HeaderColor,
				tooltip = VEQ.mylanguage.lang_Chat_QuestInfo_HeaderColor_tip,
				getFunc = VEQ.GetChat_QuestInfo_HeaderColor,
				setFunc = VEQ.SetChat_QuestInfo_HeaderColor,
				disabled = function() return not VEQ.SavedVars.Chat_QuestInfo end,
			},
			{--Chat Addon Message Header Color
				type = "colorpicker",
				name = VEQ.mylanguage.lang_Chat_QuestInfo_MsgColor,
				tooltip = VEQ.mylanguage.lang_Chat_QuestInfo_MsgColor_tip,
				getFunc = VEQ.GetChat_QuestInfo_MsgColor,
				setFunc = VEQ.SetChat_QuestInfo_MsgColor,
				disabled = function() return not VEQ.SavedVars.Chat_QuestInfo end,
			},
		},]]--
	}--zone
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_area_settings,
		controls = {
			--zone/area enabled
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_area_name,
				tooltip = VEQ.mylanguage.lang_area_name_tip,
				getFunc = VEQ.GetQuestsAreaOption,
				setFunc = VEQ.SetQuestsAreaOption,
			},
			--zone/area hybrid/pure zone
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_area_hybrid,
				tooltip = VEQ.mylanguage.lang_area_hybrid_tip,
				getFunc = VEQ.GetQuestsHybridOption,
				setFunc = VEQ.SetQuestsHybridOption,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--zone/area font
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_area_font,
				tooltip = VEQ.mylanguage.lang_area_font_tip,
				choices = fontList,
				getFunc = VEQ.GetQuestsAreaFont,
				setFunc = VEQ.SetQuestsAreaFont,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--zone/area font style
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_area_style,
				tooltip = VEQ.mylanguage.lang_area_style_tip,
				choices = fontStyles,
				getFunc = VEQ.GetQuestsAreaStyle,
				setFunc = VEQ.SetQuestsAreaStyle,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--zone/area font size
			{
				type = "slider",
				name = VEQ.mylanguage.lang_area_size,
				tooltip = VEQ.mylanguage.lang_area_size_tip,
				min = 8,
				max = 45,
				getFunc = VEQ.GetQuestsAreaSize,
				setFunc = VEQ.SetQuestsAreaSize,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--zone/area padding
			{
				type = "slider",
				name = VEQ.mylanguage.lang_area_padding,
				tooltip = VEQ.mylanguage.lang_area_padding_tip,
				min = 1,
				max = 60,
				getFunc = VEQ.GetQuestsAreaPadding,
				setFunc = VEQ.SetQuestsAreaPadding,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--zone/area color
			{
				type = "colorpicker",
				name = VEQ.mylanguage.lang_area_color,
				tooltip = VEQ.mylanguage.lang_area_color_tip,
				getFunc = VEQ.GetQuestsAreaColor,
				setFunc = VEQ.SetQuestsAreaColor,
				disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			},
			--enable auto hide zone
			-- {
				-- type = "checkbox",
				-- name = VEQ.mylanguage.lang_autohidequestzone_option,
				-- tooltip = VEQ.mylanguage.lang_autohidequestzone_option_tip,
				-- getFunc = VEQ.GetQuestsHideZoneOption,
				-- setFunc = VEQ.SetQuestsHideZoneOption,
				-- disabled = function() return not VEQ.SavedVars.QuestsAreaOption end,
			-- },
			--current zone only
			--{
				-- type = "checkbox",
				-- name = VEQ.mylanguage.lang_questzone_option,
				-- tooltip = VEQ.mylanguage.lang_questzone_option_tip,
				-- getFunc = VEQ.GetQuestsZoneOption,
				-- setFunc = VEQ.SetQuestsZoneOption,
				-- disabled = function() return not VEQ.SavedVars.QuestsAreaOption end, 
			-- },
		},
	}

	--quest settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_quests_settings,
		controls = {
			{--Number of Quests Viewable
				type = "slider",
				name = VEQ.mylanguage.lang_quests_nb,
				tooltip = VEQ.mylanguage.lang_quests_nb_tip,
				min = 1,
				max = MAX_JOURNAL_QUESTS,
				getFunc = VEQ.GetNbQuests,
				setFunc = VEQ.SetNbQuests,
			},
			{--Auto Share Quests
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_autoshare,
				tooltip = VEQ.mylanguage.lang_quests_autoshare_tip,
				getFunc = VEQ.GetAutoShareOption,
				setFunc = VEQ.SetAutoShareOption,
			},
			--[[{--Auto Untrack Hidden Quets
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_autountrack,
				tooltip = VEQ.mylanguage.lang_quests_autountrack_tip,
				getFunc = VEQ.GetQuestsUntrackHiddenOption,
				setFunc = VEQ.SetQuestsUntrackHiddenOption,
			},]]
			{--Enable Assisted Quest Icon
				type = "checkbox",
				name = VEQ.mylanguage.lang_icon_opt,
				tooltip = VEQ.mylanguage.lang_icon_opt_tip,
				getFunc = VEQ.GetQuestIconOption,
				setFunc = VEQ.SetQuestIconOption,
			},
			{--Quest Icon Size
				type = "slider",
				name = VEQ.mylanguage.lang_icon_size,
				tooltip = VEQ.mylanguage.lang_icon_size_tip,
				min = 18,
				max = 40,
				getFunc = VEQ.GetQuestIconSize,
				setFunc = VEQ.SetQuestIconSize,
				disabled = function() return not VEQ.SavedVars.QuestIconOption end,
			},
			{--Quest Icon Color
				type = "colorpicker",
				name = VEQ.mylanguage.lang_icon_color,
				tooltip = VEQ.mylanguage.lang_icon_color_tip,
				getFunc = VEQ.GetQuestIconColor,
				setFunc = VEQ.SetQuestIconColor,
				disabled = function() return not VEQ.SavedVars.QuestIconOption end,
			},
		},
		}
		
		--Quest Timer Settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_quests_timer_settings,
		controls = {
			{-- Show Timer
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_show_timer,
				tooltip = VEQ.mylanguage.lang_quests_show_timer_tip,
				getFunc = VEQ.GetQuestsShowTimerOption,
				setFunc = VEQ.SetQuestsShowTimerOption,
			},
			{--Timer Font
				type = "dropdown",
				name = VEQ.mylanguage.lang_timer_title_font,
				tooltip = VEQ.mylanguage.lang_timer_title_font_tip,
				choices = fontList,
				getFunc = VEQ.GetTimerTitleFont,
				setFunc = VEQ.SetTimerTitleFont,
				disabled = function() return not VEQ.SavedVars.QuestsShowTimerOption end,
			},
			{--Timer Style
				type = "dropdown",
				name = VEQ.mylanguage.lang_timer_title_style,
				tooltip = VEQ.mylanguage.lang_timer_title_style_tip,
				choices = fontStyles,
				getFunc = VEQ.GetTimerTitleStyle,
				setFunc = VEQ.SetTimerTitleStyle,
				disabled = function() return not VEQ.SavedVars.QuestsShowTimerOption end,
			},
			{--Timer Font Size
				type = "slider",
				name = VEQ.mylanguage.lang_timer_title_size,
				tooltip = VEQ.mylanguage.lang_timer_title_size_tip,
				min = 8,
				max = 45,
				getFunc = VEQ.GetTimerTitleSize,
				setFunc = VEQ.SetTimerTitleSize,
				disabled = function() return not VEQ.SavedVars.QuestsShowTimerOption end,
			},
			{--Timer Color Picker
				type = "colorpicker",
				name = VEQ.mylanguage.lang_timer_title_color,
				tooltip = VEQ.mylanguage.lang_timer_title_color_tip,
				getFunc = VEQ.GetTimerTitleColor,
				setFunc = VEQ.SetTimerTitleColor,
				disabled = function() return not VEQ.SavedVars.QuestsShowTimerOption end,
			},
		},--
	}
	
	
	--Quest Name Settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_titles_settings,
		controls = {
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_titles_font,
				tooltip = VEQ.mylanguage.lang_titles_font_tip,
				choices = fontList,
				getFunc = VEQ.GetTitleFont,
				setFunc = VEQ.SetTitleFont,
			},
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_titles_style,
				tooltip = VEQ.mylanguage.lang_titles_style_tip,
				choices = fontStyles,
				getFunc = VEQ.GetTitleStyle,
				setFunc = VEQ.SetTitleStyle,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_titles_size,
				tooltip = VEQ.mylanguage.lang_titles_size_tip,
				min = 8,
				max = 45,
				getFunc = VEQ.GetTitleSize,
				setFunc = VEQ.SetTitleSize,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_titles_padding,
				tooltip = VEQ.mylanguage.lang_titles_padding_tip,
				min = 1,
				max = 60,
				getFunc = VEQ.GetTitlePadding,
				setFunc = VEQ.SetTitlePadding,
			},
			{
				type = "colorpicker",
				name = VEQ.mylanguage.lang_titles_default,
				tooltip = VEQ.mylanguage.lang_titles_default_tip,
				getFunc = VEQ.GetTitleColor,
				setFunc = VEQ.SetTitleColor,
			},
		},
	}
	
	-- Objective Settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_obj_settings,
		controls = {
			{--font
				type = "dropdown",
				name = VEQ.mylanguage.lang_obj_font,
				tooltip = VEQ.mylanguage.lang_obj_font_tip,
				choices = fontList,
				getFunc = VEQ.GetTextFont,
				setFunc = VEQ.SetTextFont,
			},
			{--font style
				type = "dropdown",
				name = VEQ.mylanguage.lang_obj_style,
				tooltip = VEQ.mylanguage.lang_obj_style_tip,
				choices = fontStyles,
				getFunc = VEQ.GetTextStyle,
				setFunc = VEQ.SetTextStyle,
			},
			{--font size
				type = "slider",
				name = VEQ.mylanguage.lang_obj_size,
				tooltip = VEQ.mylanguage.lang_obj_size_tip,
				min = 8,
				max = 45,
				getFunc = VEQ.GetTextSize,
				setFunc = VEQ.SetTextSize,
			},
			{--objecitvie padding --
				type = "slider",
				name = VEQ.mylanguage.lang_obj_padding,
				tooltip = VEQ.mylanguage.lang_obj_padding_tip,
				min = 1,
				max = 60,
				getFunc = VEQ.GetTextPadding,
				setFunc = VEQ.SetTextPadding,
			},
			{-- Hide completed--
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_hide_obj_optional,
				tooltip = VEQ.mylanguage.lang_quests_hide_obj_optional_tip,
				getFunc = VEQ.GetHideCompleteObjHints,
				setFunc = VEQ.SetHideCompleteObjHints,
			},
			{-- Objective Color--
				type = "colorpicker",
				name = VEQ.mylanguage.lang_obj_color,
				tooltip = VEQ.mylanguage.lang_obj_color_tip,
				getFunc = VEQ.GetTextColor,
				setFunc = VEQ.SetTextColor,
			},
			{-- Objective Color Completed--
				type = "colorpicker",
				name = VEQ.mylanguage.lang_obj_ccolor,
				tooltip = VEQ.mylanguage.lang_obj_ccolor_tip,
				getFunc = VEQ.GetTextCompleteColor,
				setFunc = VEQ.SetTextCompleteColor,
			},
			{--Hide Optional/Hidden Quest Info/Hints ALL -- here
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_optinfos,
				tooltip = VEQ.mylanguage.lang_quests_optinfos_tip,
				getFunc = VEQ.GetHideInfoHintsOption,
				setFunc = VEQ.SetHideInfoHintsOption,
			},
			{-- Hide immersive text--
				type = "checkbox",
				name = VEQ.mylanguage.lang_quests_hide_immersive_text,
				tooltip = VEQ.mylanguage.lang_quests_hide_immersive_text_tip,
				getFunc = VEQ.GetHideImmersiveText,
				setFunc = VEQ.SetHideImmersiveText,
        disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Hide Optional Information
				type = "checkbox",
				name = VEQ.mylanguage.lang_HideOptionalInfo,
				tooltip = VEQ.mylanguage.lang_HideOptionalInfo_tip,
				getFunc = VEQ.GetHideOptionalInfo,
				setFunc = VEQ.SetHideOptionalInfo,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Hide Optional Objectives
				type = "checkbox",
				name = VEQ.mylanguage.lang_HideOptObjective,
				tooltip = VEQ.mylanguage.lang_HideOptObjective_tip,
				getFunc = VEQ.GetHideOptObjective,
				setFunc = VEQ.SetHideOptObjective,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Optional Color--
				type = "colorpicker",
				name = VEQ.mylanguage.lang_obj_optcolor,
				tooltip = VEQ.mylanguage.lang_obj_optcolor_tip,
				getFunc = VEQ.GetTextOptionalColor,
				setFunc = VEQ.SetTextOptionalColor,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Completed Optional Color Complete--
				type = "colorpicker",
				name = VEQ.mylanguage.lang_obj_optccolor,
				tooltip = VEQ.mylanguage.lang_obj_optccolor_tip,
				getFunc = VEQ.GetTextOptionalCompleteColor,
				setFunc = VEQ.SetTextOptionalCompleteColor,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Hide Hints--
				type = "checkbox",
				name = VEQ.mylanguage.lang_HideHintsOption,
				tooltip = VEQ.mylanguage.lang_HideHintsOption_tip,
				getFunc = VEQ.GetHideHintsOption,
				setFunc = VEQ.SetHideHintsOption,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Hide Hidden Hints--
				type = "checkbox",
				name = VEQ.mylanguage.lang_HideHiddenOptions,
				tooltip = VEQ.mylanguage.lang_HideHiddenOptions_tip,
				getFunc = VEQ.GetHideHiddenOptions,
				setFunc = VEQ.SetHideHiddenOptions,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Hints Color--
				type = "colorpicker",
				name = VEQ.mylanguage.lang_HintColor,
				tooltip = VEQ.mylanguage.lang_HintColor_tip,
				getFunc = VEQ.GetHintColor,
				setFunc = VEQ.SetHintColor,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
			{--Completed Hints Color--not
				type = "colorpicker",
				name = VEQ.mylanguage.lang_HintCompleteColor,
				tooltip = VEQ.mylanguage.lang_HintCompleteColor_tip,
				getFunc = VEQ.GetHintCompleteColor,
				setFunc = VEQ.SetHintCompleteColor,
				disabled = function() return VEQ.SavedVars.HideInfoHintsOption end,
			},
		},
	}--Info Settings
	optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_infos_settings,
		controls = {
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_NumbQuest_opt,
				tooltip = VEQ.mylanguage.lang_NumbQuest_opt_tip,
				getFunc = VEQ.GetShowNumbQuestOption,
				setFunc = VEQ.SetShowNumbQuestOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_ShowClock_opt,
				tooltip = VEQ.mylanguage.lang_ShowClock_opt_tip,
				getFunc = VEQ.GetShowClockOption,
				setFunc = VEQ.SetShowClockOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_ShowTbutton_opt,
				tooltip = VEQ.mylanguage.lang_ShowTbutton_opt_tip,
				getFunc = VEQ.GetShowTbuttonOption,
				setFunc = VEQ.SetShowTbuttonOption,
			},
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_infos_font,
				tooltip = VEQ.mylanguage.lang_infos_font_tip,
				choices = fontList,
				getFunc = VEQ.GetShowJournalInfosFont,
				setFunc = VEQ.SetShowJournalInfosFont,
			},
			{
				type = "dropdown",
				name = VEQ.mylanguage.lang_infos_style,
				tooltip = VEQ.mylanguage.lang_infos_style_tip,
				choices = fontStyles,
				getFunc = VEQ.GetShowJournalInfosStyle,
				setFunc = VEQ.SetShowJournalInfosStyle,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_infos_size,
				tooltip = VEQ.mylanguage.lang_infos_size_tip,
				min = 8,
				max = 45,
				getFunc = VEQ.GetShowJournalInfosSize,
				setFunc = VEQ.SetShowJournalInfosSize,
			},
			{
				type = "colorpicker",
				name = VEQ.mylanguage.lang_infos_color,
				tooltip = VEQ.mylanguage.lang_infos_color_tip,
				getFunc = VEQ.GetShowJournalInfosColor,
				setFunc = VEQ.SetShowJournalInfosColor,
			},
		},
	}
		optionsData[#optionsData + 1] = {
		type = "submenu",
		name = VEQ.mylanguage.lang_mini_quest_tracker_settings,
		controls = {
			{
			  type = "dropdown",
			  name = VEQ.mylanguage.lang_mini_quest_tracker_invert_opt,
			  tooltip = VEQ.mylanguage.lang_mini_quest_tracker_invert_tip,
			  choices = {"CTRL", "SHIFT", "ALT", "CMD"},
			  getFunc = function()  return VEQ.SavedVars.invertKey end, 
			  setFunc = function(NewVal) VEQ.SavedVars.invertKey = NewVal end,

			}, 
			{	type = "checkbox",
				name = VEQ.mylanguage.lang_ShowMQbutton_opt,
				tooltip = VEQ.mylanguage.lang_ShowMQbutton_opt_tip,
				getFunc = VEQ.GetShowMQbuttonOption,
				setFunc = VEQ.SetShowMQbuttonOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_NumbMiniQuest_opt,
				tooltip = VEQ.mylanguage.lang_NumbMiniQuest_opt_tip,
				getFunc = VEQ.GetShowNumbMiniQuestOption,
				setFunc = VEQ.SetShowNumbMiniQuestOption,
			},	
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_inventory_slots_opt,
				tooltip = VEQ.mylanguage.lang_inventory_slots_tip,
				getFunc = VEQ.GetInventorySlotsOption,
				setFunc = VEQ.SetInventorySlotsOption,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_inventory_slots_limit,
				tooltip = VEQ.mylanguage.lang_inventory_slots_limit_tip,
				min = 1,
				max = 50,
				getFunc = VEQ.GetInventorySlotsLimit,
				setFunc = VEQ.SetInventorySlotsLimit,
				disabled = function() return not VEQ.SavedVars.InventorySlots end
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_lost_treasure_opt,
				tooltip = VEQ.mylanguage.lang_lost_treasure_tip,
				getFunc = VEQ.GetLostTreasureOption,
				setFunc = VEQ.SetLostTreasureOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_skyshards_opt,
				tooltip = VEQ.mylanguage.lang_skyshards_tip,
				getFunc = VEQ.GetSkyshardsOption,
				setFunc = VEQ.SetSkyshardsOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_leads_opt,
				tooltip = VEQ.mylanguage.lang_leads_tip,
				getFunc = VEQ.GetLeadsOption,
				setFunc = VEQ.SetLeadsOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_fake_leads_opt,
				tooltip = VEQ.mylanguage.lang_fake_leads_tip,
				getFunc = VEQ.GetFakeLeadsOption,
				setFunc = VEQ.SetFakeLeadsOption, 
				disabled = function() return not VEQ.SavedVars.Leads end
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_writs_opt,
				tooltip = VEQ.mylanguage.lang_writs_tip,
				getFunc = VEQ.GetWritsOption,
				setFunc = VEQ.SetWritsOption,
				disabled = function() return WritWorthy == nil end
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_stable_opt,
				tooltip = VEQ.mylanguage.lang_stable_tip,
				getFunc = VEQ.GetStableOption,
				setFunc = VEQ.SetStableOption,
			},
						{
				type = "checkbox",
				name = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_TRIBUTE_FINDER_GENERAL_ACTIVITY_DESCRIPTOR)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				tooltip = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_TRIBUTE_FINDER_GENERAL_ACTIVITY_DESCRIPTOR)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				getFunc = VEQ.GetTributeRewardTimerOption,
				setFunc = VEQ.SetTributeRewardTimerOption,
			},
						{
				type = "checkbox",
				name = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_DUNGEON_FINDER_RANDOM_FILTER_TEXT)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				tooltip = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_DUNGEON_FINDER_RANDOM_FILTER_TEXT)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				getFunc = VEQ.GetDungeonRewardTimerOption,
				setFunc = VEQ.SetDungeonRewardTimerOption,
			},
						{
				type = "checkbox",
				name = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_BATTLEGROUND_FINDER_RANDOM_FILTER_TEXT)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				tooltip = string.format("%s: %s %s", VEQ.KillTheRubbish(GetString(SI_BATTLEGROUND_FINDER_RANDOM_FILTER_TEXT)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				getFunc = VEQ.GetBattlegroundRewardTimerOption,
				setFunc = VEQ.SetBattlegroundRewardTimerOption,
			},
						{
				type = "checkbox",
				name = VEQ.mylanguage.lang_remains_silent,
				tooltip = "< ... >",
				getFunc = VEQ.GetShadowySuppliersOption,
				setFunc = VEQ.SetShadowySuppliersOption,
			},
						{
				type = "checkbox",
				name = string.format("%s %s",VEQ.KillTheRubbish(GetAchievementName(2612)), VEQ.KillTheRubbish(GetString(SI_NOTIFICATIONTYPE21))),
				tooltip = "< ... >",
				getFunc = VEQ.GetDragonguardSupplyChestOption,
				setFunc = VEQ.SetDragonguardSupplyChestOption,
			},
						{
				type = "checkbox",
				name = string.format("%s %s", VEQ.KillTheRubbish(GetString(SI_QUESTTYPE19)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE))),
				tooltip = string.format("%s %s", VEQ.KillTheRubbish(GetString(SI_QUESTTYPE19)), VEQ.KillTheRubbish(GetString(SI_WORLD_MAP_ANTIQUITIES_AVAILABLE))),
				getFunc = VEQ.GetFavorsTimerOption,
				setFunc = VEQ.SetFavorsTimerOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_backbank_opt,
				tooltip = VEQ.mylanguage.lang_backbank_tip,
				getFunc = VEQ.GetBackbankOption,
				setFunc = VEQ.SetBackbankOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_TamrielTomes_opt,
				tooltip = VEQ.mylanguage.lang_TamrielTomes_tip,
				getFunc = VEQ.GetTamrielTomesOption,
				setFunc = VEQ.SetTamrielTomesOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_goldenPursuit_opt,
				tooltip = VEQ.mylanguage.lang_goldenPursuit_tip,
				getFunc = VEQ.GetGoldenPursuitOption,
				setFunc = VEQ.SetGoldenPursuitOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_displayTrackedGoldenPursuitOnly_opt,
				tooltip = VEQ.mylanguage.lang_displayTrackedGoldenPursuitOnly_tip,
				getFunc = VEQ.GetDisplayTrackedGoldenPursuitOnlyOption,
				setFunc = VEQ.SetDisplayTrackedGoldenPursuitOnlyOption,
			},
			{
				type = "checkbox",
				name = VEQ.KillTheRubbish(GetString(SI_GAMEPAD_QUEST_JOURNAL_RUMORS_CURRENT_MAX_LABEL)),
				tooltip = VEQ.KillTheRubbish(GetString(SI_GAMEPAD_QUEST_JOURNAL_RUMORS_CURRENT_MAX_LABEL)),
				getFunc = VEQ.GetRumorsOption,
				setFunc = VEQ.SetRumorsOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_communityEvents_opt,
				tooltip = VEQ.mylanguage.lang_communityEvents_tip,
				getFunc = VEQ.GetCommunityEventsOption,
				setFunc = VEQ.SetCommunityEventsOption,
			},			
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_tickets_opt,
				tooltip = VEQ.mylanguage.lang_tickets_tip,
				getFunc = VEQ.GetTicketsOption,
				setFunc = VEQ.SetTicketsOption,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_tickets_limit,
				tooltip = VEQ.mylanguage.lang_tickets_limit_tip,
				min = 1,
				max = 5,
				getFunc = VEQ.GetTicketsLimit,
				setFunc = VEQ.SetTicketsLimit,
				disabled = function() return not VEQ.SavedVars.Tickets end
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_transmute_opt,
				tooltip = VEQ.mylanguage.lang_transmute_tip,
				getFunc = VEQ.GetTransmuteOption,
				setFunc = VEQ.SetTransmuteOption,
			},
			{
				type = "slider",
				name = VEQ.mylanguage.lang_transmute_limit,
				tooltip = VEQ.mylanguage.lang_transmute_limit_tip,
				min = 1,
				max = 100,
				getFunc = VEQ.GetTransmuteLimit,
				setFunc = VEQ.SetTransmuteLimit,
				disabled = function() return not VEQ.SavedVars.Transmute end
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_zoneguide_opt,
				tooltip = VEQ.mylanguage.lang_zoneguide_tip,
				getFunc = VEQ.GetZoneGuideOption,
				setFunc = VEQ.SetZoneGuideOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_POIcompletion_opt,
				tooltip = VEQ.mylanguage.lang_POIcompletion_tip,
				getFunc = VEQ.GetPOIcompletionOption,
				setFunc = VEQ.SetPOIcompletionOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_poison_opt,
				tooltip = VEQ.mylanguage.lang_poison_tip,
				getFunc = VEQ.GetPoisonOption,
				setFunc = VEQ.SetPoisonOption,
			},	
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_group_frames_opt,
				tooltip = VEQ.mylanguage.lang_group_frames_tip,
				getFunc = VEQ.GetGroupFramesOption,
				setFunc = VEQ.SetGroupFramesOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_default_group_frames_opt,
				tooltip = VEQ.mylanguage.lang_default_group_frames_tip,
				getFunc = VEQ.GetDefaultGroupFramesOption,
				setFunc = VEQ.SetDefaultGroupFramesOption,
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_museum_pieces_opt,
				tooltip = VEQ.mylanguage.lang_museum_pieces_tip,
				getFunc = VEQ.GetMuseumPiecesOption,
				setFunc = VEQ.SetMuseumPiecesOption, 
			},
			{
				type = "checkbox",
				name = string.format("%s %s",VEQ.KillTheRubbish(GetString(SI_GUILDACTIVITYATTRIBUTEVALUE9)), VEQ.KillTheRubbish(GetString(SI_JOURNAL_MENU_ACHIEVEMENTS))),
				tooltip = string.format("%s %s",VEQ.KillTheRubbish(GetString(SI_GUILDACTIVITYATTRIBUTEVALUE9)), VEQ.KillTheRubbish(GetString(SI_JOURNAL_MENU_ACHIEVEMENTS))),
				getFunc = VEQ.GetFishingAchievementsOption,
				setFunc = VEQ.SetFishingAchievementsOption, 
			},
			{
				type = "checkbox",
				name = string.format("%s %s",VEQ.KillTheRubbish(GetString(SI_PATHFOLLOWTYPE2)), VEQ.KillTheRubbish(GetString(SI_GROUPFINDERPLAYSTYLE8))),
				tooltip = string.format("%s %s",VEQ.KillTheRubbish(GetString(SI_PATHFOLLOWTYPE2)), VEQ.KillTheRubbish(GetString(SI_GROUPFINDERPLAYSTYLE8))),
				getFunc = VEQ.GetRandomAchievementOption,
				setFunc = VEQ.SetRandomAchievementOption, 
			},
			{
				type = "checkbox",
				name = VEQ.mylanguage.lang_dailies_counter_opt,
				tooltip = VEQ.mylanguage.lang_dailies_counter_tip,
				getFunc = VEQ.GetDailiesCounterOption,
				setFunc = VEQ.SetDailiesCounterOption, 
			},
		},
	}
	--LAM:RegisterAddonPanel("VEQ_Settings", panelData)
	LAM:RegisterOptionControls("VEQ_Settings", optionsData)
	
	--    LAM2:RegisterAddonPanel('LUIEAddonOptions', panelData)
    --LAM2:RegisterOptionControls('LUIEAddonOptions', optionsData)
end